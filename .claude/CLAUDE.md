# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`harness-maker` ships a Claude Code Skill (`skills/harness-maker/`) that declaratively manages codebase rules via `.harness/rules.yaml` and auto-configures lint-tool, git-hook, and Claude-Code-hook enforcement. The thin `README.md` and `README.ko.md` tell an LLM how to install it (copy `skills/harness-maker/` into `.claude/skills/` or `~/.claude/skills/`). Once installed, the Skill entry point (`SKILL.md`) runs the harness-setup flow. The reference files (`skills/harness-maker/references/*.md`) expand each enforcement mechanism; the Skill loads them on demand based on the user's rule choices.

## No build / lint / test

There is nothing to run. Do not look for `package.json`, `npm test`, etc. Verifying changes = proofreading Markdown and confirming the instructions an LLM would follow still produce correct behavior in a target project.

## Structure

- `README.md` — installation guide (English). Explains what the Skill does and how to install it (copy `skills/harness-maker/` to `.claude/skills/` or `~/.claude/skills/`).
- `README.ko.md` — Korean mirror of `README.md`. **The two READMEs must stay in sync**; updating one without the other breaks the dual-language contract advertised at the top of each file.
- `skills/harness-maker/SKILL.md` — the Skill entry point. Frontmatter (`name`, `description`, trigger phrases) + the full setup procedure the LLM agent executes: (1) inspect env → (2) create `.harness/rules.yaml` → (3) pick enforcement mechanism per rule → (4) create `.claude/rules/` files → (5) scan violations → (6) report.
- `skills/harness-maker/references/project-detection.md` — how the agent detects language / package manager / linter / hook system / monorepo / existing Claude setup in the target project. This is step 1 of the Skill procedure expanded.
- `skills/harness-maker/references/eslint.md` — ESLint enforcement: flat vs legacy config, `no-restricted-syntax` AST selectors, writing custom local rules.
- `skills/harness-maker/references/git-hooks.md` — Husky v9+, native `.githooks/`, Lefthook, and Python `pre-commit` framework. Includes `commit-msg` and `pre-commit` templates.
- `skills/harness-maker/references/claude-integration.md` — `.claude/rules/*.md` advisory files and `.claude/settings.json` hooks. Defines the 4 handler types (`command`, `prompt`, `agent`, `http`) and the event/exit-code semantics.
- `skills/harness-maker/references/custom-scripts.md` — `.harness/hooks/check-*.sh|.js` scripts, the dual-mode pattern that makes one script work for both git hooks (reads stdin as tty) and Claude Code hooks (reads stdin as JSON).
- `skills/harness-maker/references/performance.md` — budgets (pre-commit ≤2s, commit-msg ≤0.5s, Claude Code hook ≤1s) and optimization patterns (staged-only filtering, `--cache`, `if` field narrowing, `command` before `prompt`).
- `skills/harness-maker/templates/rules.yaml` — starter `.harness/rules.yaml` the agent copies into the target project. Commented examples for the common rule categories.

The SKILL.md's mechanism table and the `references/` filenames are cross-referenced by link — if you rename a reference doc, fix the table in SKILL.md.

## Core concepts that must stay consistent across all docs

- **Advisory vs enforced.** `CLAUDE.md` / `.claude/rules/*.md` are advisory (the model may ignore them). Lint rules, git hooks, and Claude Code hooks are deterministic (cannot be skipped). Any new doc must preserve this framing — don't describe `.claude/rules/` as if it blocks anything.
- **Mechanism selection table** (README step 3): static analysis → lint tool; commit/push-time → git hook; semantic judgment → Claude Code `prompt` hook; codebase exploration → `agent` hook; code-generation guidance → `.claude/rules/`. Changes to this taxonomy ripple through every doc.
- **`[Harness: rule-XXX]` tag.** Every generated artifact (`.claude/rules/*.md` front-matter body, hook script header comments as `# harness: rule-XXX`) carries this tag so the harness can trace which artifact belongs to which rule for deletion / update operations. Don't drop it.
- **Never overwrite existing project config.** Every doc repeats this rule; preserve it when editing. The agent must append to existing lint configs, hook directories, and `.claude/settings.json` rather than replacing them.
- **Prefer existing tools in the target project.** If the target has Biome, route rules through Biome, not ESLint. New tool adoption requires explicit user consent.
- **Performance budgets are load-bearing.** They exist because a slow hook gets bypassed with `--no-verify`. Don't relax them without updating `skills/harness-maker/references/performance.md` in lockstep.

## When editing these docs

- Write from the point of view of an LLM agent about to operate on someone else's project — every code block is something the LLM will run in the target repo, not here.
- Keep the Korean README in lockstep with the English one. Section headings, numbered steps, tables, and example snippets must correspond 1:1.
- When you add a new enforcement pattern, put the full treatment in the relevant `references/` file and only a one-line pointer in the SKILL.md mechanism table. The README is meant to stay short enough to paste as a single prompt.
- Code snippets in the docs are templates the agent will emit into the user's project. Keep them self-contained (shebang + set flags + early exit + exit code) so they work when copied verbatim.
- The `skills/harness-maker/templates/rules.yaml` schema (fields: `id`, `name`, `description`, `severity`, `scope`, `pattern`, `examples`, `exceptions`, `check`) is the contract between SKILL.md and every `references/` file. Schema changes require a sweep of all reference docs.
