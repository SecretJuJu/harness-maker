**English** | [한국어](./README.ko.md)

# Harness

Harness is a Claude Code Skill that lets you declaratively manage codebase rules via `.harness/rules.yaml` and auto-configures lint tools, git hooks, and Claude Code hooks to enforce them.

## Install

This section is for LLM agents reading this document to help install the Harness Skill.

Before installing, **ask the user**: should this Skill be installed in the current project (scoped to `.claude/skills/harness-maker/` relative to their project root) or installed globally for all projects (`~/.claude/skills/harness-maker/`)?

**Priority order:** If the same Skill name exists in both locations, Personal (`~/.claude/skills/`) takes precedence over Project.

### Project-scoped install

```bash
mkdir -p .claude/skills
cp -r /path/to/cloned/harness-maker/skills/harness-maker .claude/skills/
```

After copying, the Skill auto-loads on the next Claude Code session. The user can then invoke it by asking "set up harness", "하네스 설정해줘", or similar trigger phrases.

### Personal/global install

```bash
mkdir -p ~/.claude/skills
cp -r /path/to/cloned/harness-maker/skills/harness-maker ~/.claude/skills/
```

After copying, the Skill auto-loads on the next Claude Code session and becomes available in every project the user opens. Trigger with "set up harness", "하네스 설정해줘", etc.

---

## What the Skill does once installed

Once the Skill is installed, it can:

- Detect your project environment (language, package manager, linter, hook system)
- Create and maintain `.harness/rules.yaml` (your declarative rule list)
- Wire rules to the right enforcement mechanism (lint tools / git hooks / Claude Code hooks / `.claude/rules/` advisory files)
- Scan existing code for rule violations and report them
- Handle requests to add, modify, or remove rules from your harness

For the full setup procedure, see `skills/harness-maker/SKILL.md`.

---

## Responding to future user requests

When the user interacts with the Skill, it handles these patterns:

| User request | Action |
|--------------|--------|
| "Add a rule to harness: ..." | Add to `rules.yaml` → configure enforcement → scan |
| "Set up harness" | Read `rules.yaml` → inspect environment → regenerate full configuration |
| "Show harness rules" | Read `rules.yaml` and pretty-print |
| "Run harness checks" | Scan violations for all active rules |
| "Delete rule-003" | Remove from `rules.yaml` + clean up related configuration |
| "Change rule-001 severity to error" | Update `rules.yaml` + propagate to related configuration |

---

## Performance budgets

Hooks must stay fast (pre-commit ≤ 2s, commit-msg ≤ 0.5s, Claude Code hook ≤ 1s) or they get bypassed. See `skills/harness-maker/references/performance.md` for details.
