# Claude-facing rule enforcement

Two places to express a rule so that Claude, not a scanner, acts on it:

- `CLAUDE.md` / `.claude/rules/*.md` — **advisory**. Loaded as context. Claude
  may ignore under load.
- `.claude/settings.json` hooks — **deterministic**. Run on lifecycle events.
  Claude cannot skip them.

Important rules should be enforced with hooks, with advisory files as a
prevention companion. Together: advisory files stop most violations before
they happen, hooks catch the rest.

For concrete check-script authoring, `if`-field syntax, exit codes, and the
settings.json wiring shape, see `custom-scripts.md`. This file focuses on the
conceptual framing and handler-type selection.

---

## CLAUDE.md / `.claude/rules/`

### Which to use

- **`CLAUDE.md`** — project-wide rules as a single document. Nested `CLAUDE.md`
  files scope rules to a subtree.
  ```
  project-root/
    CLAUDE.md          ← project-wide
    src/
      CLAUDE.md        ← applies only under src/
  ```
- **`.claude/rules/*.md`** — one file per rule. Preferred for harness because:
  - each rule lives in its own file (independent add/remove),
  - the harness can trace rule → artifact 1:1,
  - git history per rule is clearer.

### Rule file template

```markdown
---
description: Applied when editing TypeScript files under src/
globs: "src/**/*.ts"
---

# [Harness: rule-001] prefer-function-keyword

In TypeScript, declare top-level functions with `function`, not as arrow expressions.

- ✅ `export function handleClick(e: Event) { ... }`
- ❌ `export const handleClick = (e: Event) => { ... }`
- Exception: callbacks (e.g. `arr.map(x => x + 1)`).
```

Rules:
- Narrow `globs` so the rule loads only for relevant edits.
- Include the `[Harness: rule-XXX]` tag (rule-002 traceability contract).
- Always include at least one ✅ and one ❌ example.
- State exceptions explicitly.

---

## Claude Code hooks

### Overview

Claude Code runs hooks on lifecycle events. Configuration lives in
`.claude/settings.json`. For the full event list, exit-code contract, and
`matcher` / `if` grammar, see `custom-scripts.md`.

### Four handler types

| Type | Use for | Speed | Judgment |
|------|---------|-------|----------|
| `command` | Deterministic pattern matching, formatting, structural checks | Fast | None (script logic) |
| `prompt` | Rules needing semantic judgment | Medium (30s timeout) | Single-turn LLM call |
| `agent` | Rules needing codebase exploration | Slow (60s timeout) | Full tool use |
| `http` | Team policy server integration | Network-bound | Server logic |

Selection heuristic:

- Can the rule be checked with grep/AST/filename regex? → `command`.
- Is it a "does this name describe its role?" / "does this change violate the
  spirit of X?" judgment? → `prompt`.
- Does it require cross-file inspection ("is there a matching test file?")? → `agent`.
- Do you have a shared policy server? → `http`.

### Events most useful for rule enforcement

| Event | Fires | Harness use |
|-------|-------|-------------|
| `PreToolUse` | Before a tool executes | **Strongest** — can deny the tool call (exit 2 or `permissionDecision: "deny"`). |
| `PostToolUse` | After a tool executes | Auto-formatting, pattern checks, feedback to Claude. |
| `UserPromptSubmit` | User sends a prompt | Inject rule reminders, context. |
| `SessionStart` | Session begins | Inject active-rules summary so it's always in context. |
| `Stop` | Claude finishes a turn | Final verification that every rule passed. |

### Minimal settings.json

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "if": "Edit(*.ts)",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.harness/hooks/check-style.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(git commit*)",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.harness/hooks/check-commit-msg.sh"
          }
        ]
      }
    ]
  }
}
```

The `if` field narrows beyond the tool-name `matcher` and, when it does not
match, prevents the script from spawning at all. Use it to avoid running every
handler on every edit. For the full `if` grammar and its limits, see
`custom-scripts.md`.

### `prompt` handler example — semantic rule

When static analysis cannot catch a rule, lean on LLM judgment:

```json
{
  "matcher": "Edit|Write",
  "hooks": [
    {
      "type": "prompt",
      "prompt": "Check if this code change complies with project rules. Rule: function names must be verbs; variable names must describe their role. Change: $ARGUMENTS. If violated, return ok: false and a reason."
    }
  ]
}
```

Expected response from the model:

```json
{ "ok": false, "reason": "Function 'data' does not start with a verb; 'fetchData' would fit." }
```

`"ok": false` blocks the action; `reason` is surfaced back to Claude. Default
model is Haiku — fine for most rule judgments. Override with the `model`
field only when the judgment genuinely needs more capability.

### `agent` handler example — cross-file inspection

```json
{
  "matcher": "Edit|Write",
  "hooks": [
    {
      "type": "agent",
      "prompt": "Verify the modified file has a corresponding test file. If src/foo.ts was edited, tests/foo.test.ts or src/__tests__/foo.test.ts must exist."
    }
  ]
}
```

Agent handlers get Read/Grep/Glob — they can explore the repo. Powerful but
slow (60s timeout). Avoid on high-frequency events.

### Tool-family coverage

Hooks on `Edit|Write|MultiEdit` do not see `Bash` writes. Cover the full
family when enforcing filesystem state:

```json
{ "matcher": "Edit|Write|MultiEdit|Bash", "hooks": [...] }
```

Otherwise Claude can bypass via `Bash(cat > file <<EOF …)` heredocs.

---

## Advanced patterns

### SessionStart — auto-inject active rules

At session start, summarize active rules and push them into Claude's context
via `additionalContext`. Unlike `.claude/rules/`, this loads regardless of
which files get edited.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.harness/hooks/inject-rules-summary.sh"
          }
        ]
      }
    ]
  }
}
```

```bash
#!/usr/bin/env bash
# harness: dispatcher
# SessionStart: inject rule summary via additionalContext.
RULES_FILE="$CLAUDE_PROJECT_DIR/.harness/rules.yaml"
[ -f "$RULES_FILE" ] || exit 0

summary=$(python3 -c "
import yaml
with open('$RULES_FILE') as f:
    data = yaml.safe_load(f)
for r in data.get('rules', []):
    print(f\"- [{r['id']}] {r['name']}: {r['description']} (severity: {r['severity']})\")
" 2>/dev/null)
[ -z "$summary" ] && exit 0

python3 -c "
import json, sys
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'SessionStart',
    'additionalContext': '## Active harness rules\n' + '''$summary''' + '\nSee .claude/rules/ or .harness/rules.yaml.'
  }
}))
"
```

`additionalContext` is capped at 10,000 characters; keep the summary focused.

### Stop — final turn-end verification

At Stop, scan files modified this session against all active rules. Exit 2
forces Claude to continue rather than finish.

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.harness/hooks/stop/final-check.sh"
          }
        ]
      }
    ]
  }
}
```

```bash
#!/usr/bin/env bash
# harness: dispatcher (Stop)
# Final sweep of uncommitted edits for harness violations.
set -euo pipefail

modified=$(git diff --name-only 2>/dev/null | head -20)
[ -z "$modified" ] && exit 0

errors=""
for file in $modified; do
  [[ "$file" =~ \.(ts|tsx)$ ]] || continue
  [ -f "$file" ] || continue
  if grep -qE '^(export )?(const|let) \w+ = (\(|async \()' "$file"; then
    errors="${errors}\n - $file: arrow function export found"
  fi
done

if [ -n "$errors" ]; then
  { echo "harness[Stop]: remaining violations:"; printf '%b\n' "$errors"; echo "Fix and try again."; } >&2
  exit 2
fi
exit 0
```

Stop hook runs on every turn — keep it fast. Use `--cache` for lint tools
and restrict the scan to recently modified files.

---

## Rule type → recommended combination

Primary enforcement in the first column; advisory companion in the second.

| Rule type | Advisory (prevention) | Enforcement (detection) |
|-----------|----------------------|-------------------------|
| Code style pattern | `.claude/rules/` | `command` hook (PostToolUse) |
| Commit-message format | `.claude/rules/` | `command` hook (PreToolUse + `if: "Bash(git commit*)"`) |
| Naming convention | `.claude/rules/` | `prompt` hook (PostToolUse) |
| Architecture rule | `.claude/rules/` | `agent` hook (PostToolUse) |
| Test-file required | `.claude/rules/` | `agent` hook (Stop) |
| Forbidden pattern (e.g. import) | `.claude/rules/` | `command` hook (PostToolUse) |
| Task-scoped procedure (file placement, scaffolding) | `.claude/rules/` | **Skill** (see `skills.md`) + optional `command` PostToolUse |

---

## Inspecting the existing setup

```bash
cat CLAUDE.md 2>/dev/null | head -30
ls .claude/rules/ 2>/dev/null
cat .claude/settings.json 2>/dev/null
find . -name "CLAUDE.md" -maxdepth 3 2>/dev/null
```

When existing `CLAUDE.md` is present, preserve its content and append in the
correct section. When existing hooks are configured, add new entries under the
existing event keys — **never overwrite**.

---

## Cross-reference

- `custom-scripts.md` — full `if`-field grammar, exit-code contract, dispatcher trade-offs, dual-mode scripts, tool-family coverage.
- `skills.md` — Skill-based enforcement for task-scoped procedure rules.
- `performance.md` — budgets and optimization patterns for Claude Code hooks.

## Sources

- Claude Code hooks reference — `https://code.claude.com/docs/en/hooks`
- Claude Code settings reference — `https://code.claude.com/docs/en/settings`
