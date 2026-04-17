---
description: SKILL.md links to references/*.md must point at files that exist.
globs: "skills/harness-maker/SKILL.md,skills/harness-maker/references/*.md"
---

# [Harness: rule-003] skill-references-cross-ref

`skills/harness-maker/SKILL.md` includes a mechanism guide that links to `references/*.md` files. When a reference file is renamed, deleted, or newly added, the corresponding link in SKILL.md must change in the same commit.

- ✅ Good: Renaming `references/eslint.md` → `references/linter.md` also updates the bullet and any inline mentions in `SKILL.md`.
- ❌ Bad: A reference file is renamed without touching `SKILL.md` — the documented link no longer resolves.
- Exception: None.

Enforcement: `.harness/hooks/check-skill-refs.sh` run by the `pre-commit` git hook extracts every `references/*.md` mention from `SKILL.md` and fails if any of them do not exist on disk.
