**English** | [한국어](./README.ko.md)

# Harness

A system that lets you declaratively define codebase rules and auto-configures your working environment to enforce them.

## Usage

Paste this prompt into an LLM agent (Claude Code, Cursor, Copilot, etc.):

```
Read this document and set up harness for my project:
https://raw.githubusercontent.com/{owner}/harness-maker/main/README.md
```

---

## Instructions for LLM agents

> The following is for LLM agents reading this document.
> It describes how to set up harness in the user's project.

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
    severity: warn             # warn | error
    scope:
      languages: [typescript]  # Target languages (optional)
      glob: "src/**/*.ts"      # Target file pattern (optional)
      trigger: commit          # code | commit | push (optional)
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

#### 3. Configure enforcement mechanisms per rule

For each rule in `rules.yaml`, pick and configure an enforcement mechanism suited to the project.

**Mechanism selection guide:**

| Question | Mechanism |
|----------|-----------|
| Can it be caught by static analysis? | The project's lint tool (ESLint, Biome, Ruff, Clippy, etc.) |
| Only relevant at commit/push time? | git hook (Husky, Lefthook, native, pre-commit, etc.) |
| Semantic rule requiring LLM judgment? | Claude Code `prompt` hook |
| Needs codebase exploration? | Claude Code `agent` hook |
| Should Claude know when generating code? | `.claude/rules/` file |

**Important:** It is common to combine several mechanisms for a single rule.
- `.claude/rules/` = **advisory** (Claude may ignore it)
- Lint tools, git hooks, Claude Code hooks = **enforced** (cannot be skipped)

**Prefer existing tools.**
If the project already has ESLint, add rules to ESLint; if Biome, add them to Biome.
Introduce a new tool only with the user's consent.

**Never overwrite existing configuration.**
Append to existing content or adapt to existing patterns.

For concrete implementation details per mechanism, see the `docs/` directory:
- `docs/eslint.md` — ESLint flat/legacy config, no-restricted-syntax, custom rules
- `docs/git-hooks.md` — Husky, Lefthook, native hooks, pre-commit (Python)
- `docs/claude-integration.md` — .claude/rules/, Claude Code hooks (4 handler types)
- `docs/custom-scripts.md` — Custom check scripts, patterns compatible with both git hooks and Claude Code hooks
- `docs/performance.md` — Hook performance budgets, cost per handler type, optimization patterns

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

For detailed performance optimization, see `docs/performance.md`.
