**English** | [한국어](./README.ko.md)

# Harness

Harness is a pair of Claude Code Skills that let you declaratively manage codebase rules via `.harness/rules.yaml` and auto-configure lint tools, git hooks, and Claude Code hooks to enforce them.

- **`harness-maker`** — for the maintainer who sets up or evolves the harness (adds rules, wires enforcement, scans violations).
- **`apply-harness`** — for contributors who clone the repo and need to activate the shared harness on their local machine (git hooks are per-clone state and do not travel with the repo).

## Install

This section is for LLM agents reading this document to help install the Harness Skills.

Before installing, **ask the user**: should these Skills be installed in the current project (scoped to `.claude/skills/` relative to their project root) or installed globally for all projects (`~/.claude/skills/`)?

**Priority order:** If the same Skill name exists in both locations, Personal (`~/.claude/skills/`) takes precedence over Project.

**Both Skills should be installed together** — contributors need `apply-harness`, maintainers need both.

### Project-scoped install

```bash
mkdir -p .claude/skills
cp -r /path/to/cloned/harness-maker/skills/harness-maker .claude/skills/
cp -r /path/to/cloned/harness-maker/skills/apply-harness .claude/skills/
```

After copying, the Skills auto-load on the next Claude Code session. Maintainers invoke with "set up harness", "하네스 설정해줘". Contributors invoke with "apply harness", "하네스 적용".

### Personal/global install

```bash
mkdir -p ~/.claude/skills
cp -r /path/to/cloned/harness-maker/skills/harness-maker ~/.claude/skills/
cp -r /path/to/cloned/harness-maker/skills/apply-harness ~/.claude/skills/
```

After copying, both Skills auto-load on the next Claude Code session and become available in every project the user opens.

---

## What the Skills do once installed

### `harness-maker` (for maintainers)

- Detect your project environment (language, package manager, linter, hook system)
- Create and maintain `.harness/rules.yaml` (your declarative rule list)
- Wire rules to the right enforcement mechanism (lint tools / git hooks / Claude Code hooks / `.claude/rules/` advisory files)
- Scan existing code for rule violations and report them
- Handle requests to add, modify, or remove rules from your harness

For the full setup procedure, see `skills/harness-maker/SKILL.md`.

### `apply-harness` (for contributors)

- Verify `.harness/rules.yaml` exists in the clone
- Detect the hook runner the maintainer chose (native `.githooks/`, Husky, Lefthook, or pre-commit)
- Activate it locally (`git config core.hooksPath …`, `husky install`, `lefthook install`, `pre-commit install`)
- Make `.harness/hooks/*.sh` executable
- Remind the contributor to install linter dependencies if missing
- Be idempotent — safe to re-run on an already-applied clone

For the full activation procedure, see `skills/apply-harness/SKILL.md`.

---

## Responding to future user requests

### `harness-maker`

| User request | Action |
|--------------|--------|
| "Add a rule to harness: ..." | Add to `rules.yaml` → configure enforcement → scan |
| "Set up harness" | Read `rules.yaml` → inspect environment → regenerate full configuration |
| "Show harness rules" | Read `rules.yaml` and pretty-print |
| "Run harness checks" | Scan violations for all active rules |
| "Delete rule-003" | Remove from `rules.yaml` + clean up related configuration |
| "Change rule-001 severity to error" | Update `rules.yaml` + propagate to related configuration |

### `apply-harness`

| User request | Action |
|--------------|--------|
| "Apply harness" / "하네스 적용" | Detect hook runner → activate it locally → verify lint deps |
| "Onboard to harness" | Same as above; idempotent if already applied |

---

## Performance budgets

Hooks must stay fast (pre-commit ≤ 2s, commit-msg ≤ 0.5s, Claude Code hook ≤ 1s) or they get bypassed. See `skills/harness-maker/references/performance.md` for details.
