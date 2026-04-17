---
description: README.md and README.ko.md are a 1:1 bilingual contract — always edit both together.
globs: "README*.md"
---

# [Harness: rule-001] readme-dual-language-sync

`README.md` (English) and `README.ko.md` (Korean) advertise a dual-language contract at the top of each file. Their section headings, numbered steps, tables, and example snippets must correspond 1:1.

- ✅ Good: A single commit updates both `README.md` and `README.ko.md` with matching structure.
- ❌ Bad: Only `README.md` is modified; the Korean mirror drifts out of sync until someone notices.
- Exception: None. Even one-sided typo fixes should be paired so the contract holds.

Enforcement: `.harness/hooks/check-readme-sync.sh` run by the `pre-commit` git hook blocks commits where only one side is staged.
