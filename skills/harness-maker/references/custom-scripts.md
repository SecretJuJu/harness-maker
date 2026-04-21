# Custom check scripts — authoring and wiring

Deterministic enforcement for rules that the project's lint tool cannot express.
Check scripts are invoked from git hooks, from Claude Code hooks, or directly from
the CLI, ideally all three from the same file.

## When to use a check script

- The rule cannot be expressed in the project's lint tool (ESLint, Biome, Ruff, Clippy).
- The rule concerns **file structure / directory layout** (e.g. "every `features/*` directory must contain `index.ts`").
- The rule concerns **cross-file relationships** (e.g. "every component file has a corresponding test file").
- The rule concerns **non-code artifacts** (README presence, config files, filename conventions, bilingual-doc sync).
- The target language has no linter reference implementation — `grep`/`awk` on file contents is the fallback.

The script is the deterministic enforcement; `.claude/rules/*.md` stays as the advisory companion.

## File layout

```
.harness/
  hooks/
    check-<rule-name>.sh         # one script per rule
    post-tool/                   # optional: Claude Code PostToolUse wrappers
      check-<rule-name>.sh
    stop/                        # optional: Claude Code Stop wrappers
      check-<rule-name>.sh
```

Keep a single script per rule so the `[Harness: rule-XXX]` tag maps 1:1 to a
file (rule-002 traceability) and rule deletion is `rm` of one script plus the
matching `settings.json` entry.

## Authoring principles

- **Exit codes** — see "Hook exit code contract" below:
  - `0` = pass.
  - `2` = blocking error; stderr is fed back to Claude / aborts the git action.
  - `1` = non-blocking error; stderr only reaches the debug log. Rarely what
    you want for enforcement.
- **Output on stderr**, not stdout. Exit-2 feedback flows through stderr; stdout
  is reserved for optional JSON output (see below).
- **Quote file + line** of every violation so Claude and humans can jump to it.
- **Performance budget**: pre-commit ≤2s, commit-msg ≤0.5s, Claude Code hook ≤1s.
  See `performance.md`.
- **Staged-file optimization**: accept file paths via argv/stdin; default to
  `git diff --cached --name-only --diff-filter=ACM` when invoked with no args.
  Never scan the whole repo unless explicitly requested.
- **Executable bit**: `chmod +x` is load-bearing. Unset permissions silently
  break hooks.
- **Idempotent**: repeated runs produce the same result; no disk writes.
- **Rule tag**: `# harness: rule-XXX` header comment (rule-002).

## Dual-mode scripts — one file, two callers

A check script should run from both a git hook (stdin is a TTY, file list from
argv or `git diff --cached`) and a Claude Code hook (stdin is JSON with
`tool_input.file_path`). Detecting the caller lets one script serve both and
keeps the `[Harness: rule-XXX]` 1:1 mapping clean.

```bash
#!/usr/bin/env bash
# harness: rule-001
# check-no-arrow-exports.sh — works as git hook AND Claude Code PostToolUse hook
set -euo pipefail

if [ -t 0 ]; then
  # stdin is a terminal → git hook / manual CLI invocation
  files="${*:-$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|tsx)$' || true)}"
else
  # stdin is a pipe → Claude Code hook; parse JSON payload
  input=$(cat)
  file_path=$(printf '%s' "$input" | python3 -c \
    'import json,sys; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)
  files="$file_path"
fi

[ -z "$files" ] && exit 0

errors=0
for file in $files; do
  [[ "$file" =~ \.(ts|tsx)$ ]] || continue
  [ -f "$file" ] || continue
  matches=$(grep -nE "^export (const|let) \w+ = (\(|async \()" "$file" 2>/dev/null || true)
  if [ -n "$matches" ]; then
    {
      printf 'harness[rule-001] %s:\n%s\n' "$file" "$matches"
      echo "  fix: declare with 'function' instead of an arrow export."
    } >&2
    errors=$((errors + 1))
  fi
done

[ "$errors" -gt 0 ] && exit 2
exit 0
```

## Wiring scripts to Claude Code hooks

### Recommended pattern

After reviewing the official reference (`https://code.claude.com/docs/en/hooks`)
and the main open-source exemplars
(`disler/claude-code-hooks-mastery`,
`smykla-skalski/klaudiush`,
`disler/claude-code-hooks-multi-agent-observability`) as of 2026-04, the
community-consensus shape for an enforcement harness is:

**one broad `matcher` per tool family → one handler per rule, each scoped with `if` → one script per rule.**

The engine already dispatches, **deduplicates identical `command` strings**, and
runs matched handlers in parallel — a custom fan-out dispatcher is redundant.

```json
// .claude/settings.json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "if": "Edit(*.ts)",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.harness/hooks/check-no-arrow-exports.sh"
          },
          {
            "type": "command",
            "if": "Write(scheme/*.sql)",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.harness/hooks/check-scheme-filename.sh"
          }
        ]
      }
    ]
  }
}
```

Rules of thumb:

- **Broad matcher**, **narrow `if`**. `matcher` filters tool name only; `if`
  gates process startup — the script doesn't spawn when `if` does not match.
- Reference scripts with **`$CLAUDE_PROJECT_DIR`** so paths resolve regardless
  of cwd. Quote it because the path may contain spaces:
  `"\"$CLAUDE_PROJECT_DIR\"/.harness/hooks/…"`.
- Same `command` string under multiple matcher blocks is **deduped
  automatically** — safe to register the same script across events.
- Handlers under one matcher run **in parallel**; assume no ordering.

### `if` field syntax and limits

The `if` field uses Claude Code **permission-rule syntax** — the same grammar
as the permission allow-list — **not** shell glob and **not** regex.

| Pattern | What it matches |
|---------|-----------------|
| `Edit(*.ts)` | `tool_input.file_path` whose **basename** matches `*.ts` |
| `Write(scheme/*)` | `file_path` whose path matches `scheme/*` at one level |
| `Bash(git push *)` | any parsed subcommand matches `git push *` |
| `mcp__memory__.*` | (matcher only, regex) tool name match |

Constraints:

- **`**` does NOT recurse across directory boundaries.** The pattern grammar is
  flat. For recursive path filters, parse `tool_input.file_path` inside the
  script and early-exit.
- **One rule per `if`.** No `&&` / `||` / lists. For multiple conditions,
  register multiple handler entries.
- **`if` is evaluated only on tool events**: `PreToolUse`, `PostToolUse`,
  `PostToolUseFailure`, `PermissionRequest`. On other events (`Stop`,
  `UserPromptSubmit`, `SessionStart`, …) a handler with `if` set **never
  runs** — filter inside the script instead.
- **Unparseable Bash commands always match.** Never rely on `if` alone as a
  deny gate; re-parse `tool_input.command` in the script for deny rules.
- **Leading `VAR=value` is stripped** before Bash subcommand matching, so
  `Bash(git push *)` matches `FOO=bar git push …`. Compound commands like
  `npm test && git push` match any subcommand — be defensive.

### Hook exit code contract

| Exit | Universal meaning | PreToolUse effect | PostToolUse effect | Stop / UserPromptSubmit effect |
|------|-------------------|-------------------|--------------------|--------------------------------|
| `0`  | success; stdout parsed as JSON (see below) | allow | success | allow |
| `2`  | blocking; stdout ignored, **stderr fed to Claude as error** | **denies tool** | feedback to Claude (tool already ran) | **blocks Stop** / erases prompt |
| `1` or other | non-blocking log; stderr in debug log only | tool runs | tool effect stands | action continues |

**Common misbelief to avoid:** `exit 1` is NOT the right signal for enforcement
— Claude does not see the message on most events. For any hook that must
surface feedback to Claude, use **exit 2** with the message on **stderr**.

### JSON output — structured feedback (preferred for rich cases)

Instead of stderr+exit-2, a hook may exit 0 with JSON on stdout. This is the
cleanest shape for PostToolUse feedback and the only way to set
`additionalContext`, `systemMessage`, or a PreToolUse `permissionDecision`:

```bash
cat <<'EOF'
{
  "decision": "block",
  "reason": "harness[rule-001]: export arrow function in src/auth.ts:12 — use 'function' keyword."
}
EOF
exit 0
```

PreToolUse supports `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "..."}}` for richer permission-style control. When multiple PreToolUse hooks return different decisions, precedence is `deny > defer > ask > allow`.

Caps:
- `additionalContext`, `systemMessage`, and plain stdout injected into Claude's
  context are **limited to 10,000 characters**; longer output is saved to a
  file and replaced with a preview. Keep messages focused.

### Tool-family coverage — the Bash escape hatch

A hook on `Edit|Write|MultiEdit` does not see Bash writes. If a rule forbids a
filesystem state (forbidden file, filename pattern), cover the `Bash` family
too:

```json
{ "matcher": "Edit|Write|MultiEdit|Bash", "hooks": [...] }
```

Otherwise Claude can bypass by writing via `Bash(cat > file <<EOF …)` heredocs
or `Bash(echo ... > file)`.

### Timeouts and async

- `timeout` default: command=600s, prompt=30s, agent=60s. Override per handler.
- `async: true` runs in background, never blocks Claude. Use only for logging,
  metrics, or non-enforcement observers.
- `asyncRewake: true` runs in background and wakes Claude on exit 2, feeding
  stderr as a system reminder. Useful for long-running watchers (lint servers,
  test runs).

## Wiring scripts to git hooks

Git hooks need a dispatcher because git's hook system has no built-in fan-out:
one hook file per event. Compose the fan-out yourself.

```bash
#!/usr/bin/env bash
# .githooks/pre-commit — harness dispatcher
# Runs every .harness/hooks/check-*.sh sequentially; aggregates failures.
set -uo pipefail

failed=0
for script in .harness/hooks/check-*.sh; do
  [ -x "$script" ] || continue
  "$script" || failed=1
done
exit $failed
```

Activate with `git config core.hooksPath .githooks`, or via Husky/Lefthook; see
`git-hooks.md`.

## When a dispatcher **is** warranted for Claude Code

Reach for a custom dispatcher only when:

- **Dynamic registration** — rules live outside `settings.json` (read from
  `.harness/rules.yaml` at runtime) and the active set changes without
  redeploying settings. Example pattern: `klaudiush` auto-registers validators
  by predicate.
- **Cross-event observability** — forwarding all 20+ hook events to one
  endpoint / audit log. Example pattern:
  `claude-code-hooks-multi-agent-observability`.
- **Predicate logic `if` cannot express** — cross-file state, session-level
  context, or regex that exceeds permission-rule grammar.

For everyday enforcement harnesses, the built-in matcher + `if` + per-rule
handler wiring is:
- simpler (no dispatcher process spawn overhead),
- preserves the `[Harness: rule-XXX]` 1:1 file-to-rule mapping,
- lets the engine dedupe identical commands across matcher blocks and
  parallelize unrelated handlers.

## Cross-reference

- `claude-integration.md` — full `.claude/rules/*.md` and Claude Code hook
  conceptual reference (advisory vs enforced framing, SessionStart/Stop
  advanced patterns).
- `git-hooks.md` — Husky / Lefthook / native `.githooks/` / Python
  `pre-commit` framework specifics.
- `performance.md` — hook performance budgets and optimization patterns.

## Sources

- Claude Code hooks reference — `https://code.claude.com/docs/en/hooks`
- Claude Code settings reference — `https://code.claude.com/docs/en/settings`
- Claude Code permission rule syntax — `https://code.claude.com/docs/en/permissions`
- Community exemplars:
  `disler/claude-code-hooks-mastery` (per-event script pattern),
  `smykla-skalski/klaudiush` (dispatcher + predicate-based validator registration),
  `disler/claude-code-hooks-multi-agent-observability` (cross-event forwarder).
