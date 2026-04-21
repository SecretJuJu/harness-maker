---
name: harness-maker
description: Declare coding rules in .harness/rules.yaml and auto-configure the project environment (lint tools, git hooks, Claude Code hooks, .claude/rules/) to enforce them. Use when the user wants to set up harness, add a coding rule, declare a rules.yaml entry, run harness checks, or manage project-wide enforcement. Trigger phrases include "harness 설정", "하네스 추가", "하네스 구성", "코딩 규칙 선언", "rules.yaml", "set up harness", "add harness rule", "enforce coding rule".
---

# Harness

You **declare** coding rules in `.harness/rules.yaml`, and harness **auto-configures**
the project environment to enforce them.

```
.harness/rules.yaml  →  agent reads  →  lint config, git hooks,
(declaration: what)      & configures     .claude/rules/, etc.
                                          (implementation: how)
```

### What is harness

You **declare** coding rules in `.harness/rules.yaml`, and harness **auto-configures**
the project environment to enforce them.

```
.harness/rules.yaml  →  agent reads  →  lint config, git hooks,
(declaration: what)      & configures     .claude/rules/, etc.
                                          (implementation: how)
```

### Setup procedure

#### 1. Inspect the project environment

First, analyze the user's project:

```bash
# Project root
ls -la

# Language & package manager
ls package.json Cargo.toml pyproject.toml go.mod 2>/dev/null
ls package-lock.json yarn.lock pnpm-lock.yaml bun.lockb 2>/dev/null

# Linters/formatters
ls .eslintrc* eslint.config.* biome.json .prettierrc* deno.json 2>/dev/null
ls .ruff.toml ruff.toml clippy.toml .golangci.yml 2>/dev/null

# Hook systems
ls -la .husky/ .githooks/ .lefthook* .pre-commit-config.yaml 2>/dev/null

# Claude configuration
ls CLAUDE.md .claude/ 2>/dev/null

# Existing harness
cat .harness/rules.yaml 2>/dev/null
```

#### 2. Create `.harness/rules.yaml`

Create a `.harness/` directory and `rules.yaml` at the project root.

```bash
mkdir -p .harness
```

The schema of `rules.yaml` is:

```yaml
rules:
  - id: rule-001
    name: rule-name            # kebab-case
    description: "Rule description"
    kind: code-constraint      # task-procedure | code-constraint | repo-invariant (optional, see §3 Q1)
    severity: warn             # warn | error
    scope:
      languages: [typescript]  # Target languages (optional)
      glob: "src/**/*.ts"      # Target file pattern (optional)
      task_triggers:           # For kind: task-procedure — phrases that should invoke the Skill
        - "design a table"
        - "schema change"
      trigger: commit          # code | commit | push (optional; repo-invariant rules only)
    pattern: 'regex'           # For string-matching rules (optional)
    examples:
      good: "good example code"
      bad: "bad example code"
    exceptions: "Exception notes"            # optional
    check: ".harness/hooks/script.sh"        # Custom check script (optional)
```

**Ask the user which rules they want.**
Feel free to suggest useful rules based on the project's environment.

Commonly useful rule examples:
- Commit message format (Conventional Commits, etc.)
- Import path rules (no relative imports, use package names, etc.)
- Code style (function declaration style, no default exports, etc.)
- Architectural rules (dependency direction between layers, etc.)

#### 3. Classify the rule, then pick the mechanism

The most common failure mode is reaching for a pre-commit hook by default. Before
configuring anything, **classify what kind of rule this actually is**. The rule's
*nature* decides the primary mechanism; the question of *who violates* is a
secondary, post-hoc question used only to decide whether to add a backstop.

##### Q1 — Is this rule a *task-scoped procedure* rather than a *constraint on all code*?

A task-scoped procedure is a *how-to* that applies only when a specific kind of
work is being done. The trigger is **the task itself**, not a file pattern or
a commit event.

Examples:
- "When designing a table, save SQL as `scheme/YYYYMMDD_TableName.sql`."
- "When adding a new API endpoint, update `docs/api.md` and the Postman collection."
- "When creating a React page, scaffold it from our template."

These are not violations a scanner can catch after the fact — the question is
*"did you follow the right procedure for this kind of work?"*, and often the
violation is **absence** (forgot to create the artifact at all), which no
pattern match can detect.

→ **Primary mechanism: a Skill** under `.claude/skills/<skill-name>/SKILL.md`.
  The Skill's `description` carries the trigger phrases (`scope.task_triggers`
  from `rules.yaml`) so Claude invokes it automatically *at task start*. The
  Skill's body walks the agent through the procedure, preventing the violation
  instead of detecting it later.
  Pair with a `.claude/rules/*.md` advisory as a fallback for when the task
  phrasing doesn't fire the Skill.

See `references/skills.md` for the full Skill authoring pattern.

If the rule isn't task-scoped, continue to Q2.

##### Q2 — Is this rule an *always-on constraint* on code content?

It applies to every file of a given kind, regardless of the task.

Examples:
- "No `any` in TypeScript."
- "Functions declared with `function`, not arrow."
- "No relative imports across `src/` boundaries."

→ **Primary mechanism: the project's lint tool** (ESLint, Biome, Ruff, Clippy).
  Editor integration gives feedback in milliseconds — faster than any hook.
  Pair with `.claude/rules/*.md` so Claude writes it right the first time.

If the rule isn't a content constraint, continue to Q3.

##### Q3 — Is this rule about *repository / git state*?

It only becomes meaningful at a git event.

Examples:
- "Commit messages follow Conventional Commits."
- "No direct push to `main`."
- "`README.md` and `README.ko.md` must change together."

A lint tool can't see these; a Skill can't enforce them deterministically.

→ **Primary mechanism: git hook** (`commit-msg`, `pre-commit`, `pre-push`).

##### Q4 — Who produces violations? (backstop question, answered last)

Only after the primary mechanism is chosen, decide whether a second line of
defense is needed.

| Primary producer | Backstop decision |
|------------------|-------------------|
| Claude (generation) | Add a `PostToolUse` or `Stop` Claude Code hook if the primary is advisory (Skill, `.claude/rules/`). |
| Humans (typing) | Editor-integrated linter usually suffices. Add a git hook only if a miss must not reach the repo. |
| Both | Combine Claude Code hook + git hook only when the rule is truly critical. |

**Pre-commit is a last resort, not a default.** If a Skill, a lint rule, or a
`PostToolUse` hook can catch the issue earlier, prefer those — violations
caught at commit time have already cost the author their flow state, and the
common reflex is to bypass with `--no-verify`.

---

##### Anti-patterns

- ❌ **Treating every rule as a violation to catch at commit.** Many "rules"
  are procedures; procedures belong in a Skill, invoked at task start.
- ❌ **Reaching for `pre-commit` as the first answer.** It's the *last* line
  of defense. Classify the rule first (Q1–Q3).
- ❌ **Using `.claude/rules/` alone for a procedure.** Advisory files can
  be ignored. A procedure rule needs a Skill so the task description itself
  pulls Claude into the flow.
- ❌ **Using a git hook to enforce *absence*.** If the violation is "you
  forgot to create the file", a filename-regex pre-commit hook can't help —
  there's nothing staged to inspect. Move the rule to a Skill.
- ❌ **Skipping the lint tool when one exists.** If Biome/ESLint/Ruff is
  already configured, route lint-able rules through it before writing a hook.

---

##### Rule archetype → mechanism cheat sheet

| Archetype | Primary | Backstop |
|-----------|---------|----------|
| Task-scoped procedure (file placement, scaffolding, template-following) | **Skill** | `.claude/rules/` + `PostToolUse` filename/shape check |
| Always-on code constraint (TS `no-any`, import rules, style) | **Lint rule** | `.claude/rules/` + optional `PostToolUse` grep |
| Semantic code-quality (naming, design smell) | `.claude/rules/` + Claude Code `prompt` hook | — |
| Cross-artifact consistency (test-per-module, doc-per-endpoint) | Claude Code `agent` hook (`PostToolUse` or `Stop`) | Git `pre-commit` if critical |
| Commit-message / branch-name format | Git `commit-msg` / `pre-push` hook | `.claude/rules/` for Claude-authored commits |
| Repository invariant (bilingual docs sync, forbidden files) | Git `pre-commit` hook | `.claude/rules/` advisory |

---

**Never overwrite existing configuration.** Append to existing content or adapt
to existing patterns.

**Prefer existing tools.** If the project already has ESLint, add rules to
ESLint; if Biome, add them to Biome. Introduce a new tool only with the user's
consent.

**When wiring Claude Code hooks**, follow the community-consensus shape: one
broad `matcher` per tool family, one handler per rule scoped with an `if`
clause, one script per rule. Use **exit 2** (not exit 1) to surface feedback to
Claude; parse `tool_input.file_path` in-script for recursive path predicates
that the flat `if` grammar cannot express. Cover the `Bash` tool family when a
rule forbids a filesystem state (otherwise `cat > file <<EOF` heredocs bypass
Edit/Write hooks). See `references/custom-scripts.md` for the full contract.

For concrete implementation details per mechanism, see the `references/` directory:
- `references/skills.md` — Skill authoring for task-scoped procedure rules (primary mechanism for `kind: task-procedure`)
- `references/eslint.md` — ESLint flat/legacy config, no-restricted-syntax, custom rules
- `references/git-hooks.md` — Husky, Lefthook, native hooks, pre-commit (Python)
- `references/claude-integration.md` — .claude/rules/, Claude Code hooks (4 handler types)
- `references/custom-scripts.md` — Check-script authoring + Claude Code hook wiring best practices (matcher/`if`/exit-code contract, dual-mode scripts, when a dispatcher is actually warranted)
- `references/performance.md` — Hook performance budgets, cost per handler type, optimization patterns

#### 4. Create `.claude/rules/` files

Create a Claude-facing rule file for each rule.
Use the `examples` and `exceptions` fields from `rules.yaml`.

```markdown
<!-- .claude/rules/rule-name.md -->
---
description: Rule description
globs: "src/**/*.ts"
---

# [Harness: rule-001] Rule name
Rule description.

- ✅ Good: `good example code`
- ❌ Bad: `bad example code`
- Exception: Exception notes
```

#### 5. Scan for violations and report

Once setup is complete, scan the current code for violations.

If there are many violations, present options to the user:
- Batch-fix auto-fixable ones with `--fix`
- Start with `severity: warn` and fix gradually
- Narrow the scope so it applies only to new code

#### 6. Report results to the user

After completing setup, tell the user:
- The list of added rules
- Which mechanism enforces each rule
- The current violation count (if any)
- A reminder to commit `.harness/` to git
- A reminder that git-hook activation is **per-clone local state**: teammates who clone the repo must run the sibling `apply-harness` Skill (or the equivalent `git config core.hooksPath …` / `husky install` command) before the hooks fire on their machine

---

### Responding to future user requests

| User request | Action |
|--------------|--------|
| "Add a rule to harness: ..." | Add to `rules.yaml` → configure enforcement → scan |
| "Set up harness" | Read `rules.yaml` → inspect environment → regenerate full configuration |
| "Show harness rules" | Read `rules.yaml` and pretty-print |
| "Run harness checks" | Scan violations for all active rules |
| "Delete rule-003" | Remove from `rules.yaml` + clean up related configuration |
| "Change rule-001 severity to error" | Update `rules.yaml` + propagate to related configuration |

### Performance budgets

When writing hooks or scripts, follow these budgets:
- pre-commit hook: under 2s
- commit-msg hook: under 0.5s
- Claude Code command hook: under 1s
- Check only staged files, exit early, use lightweight tools

For detailed performance optimization, see `references/performance.md`.
