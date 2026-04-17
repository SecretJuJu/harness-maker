# [Harness: rule-006] skills-readme-sync

Whenever you modify anything under `skills/**`, decide whether the change is user-facing enough to warrant a README update. `README.md` (English) and `README.ko.md` (Korean) are the front door for anyone installing or using the Skills — if they drift, new users get wrong information.

- ✅ Good: Adding a new Skill → add an install block, description, and trigger-phrase row to **both** READMEs in the same commit. Renaming a Skill or a trigger phrase → update every README mention.
- ❌ Bad: Skill behavior or trigger phrases change but the READMEs still describe the old state.
- Exception: Pure internal refactors with no user-visible change (typo fix in a reference file, restructuring `templates/` without changing its public shape).

Per rule-001, the two READMEs must stay in lockstep: update both or neither.

Enforcement: `.harness/hooks/stop/check-skills-readme.sh` runs as a Claude Code **Stop** hook. When your turn ends with uncommitted `skills/**` changes but no README edits, it prints a non-blocking reminder (exits 0) so you can review before the next turn or commit. There is intentionally no git-hook backstop for this rule because the decision is semantic and should not block human committers.
