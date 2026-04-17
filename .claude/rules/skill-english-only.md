# [Harness: rule-005] skill-english-only

All harness-maker Skill content — `skills/harness-maker/SKILL.md`, `skills/harness-maker/references/*.md`, and everything under `skills/harness-maker/templates/` — must be written in English. The Skill is consumed by LLM agents across projects; mixed-language content causes inconsistent interpretation and reduces reusability. Hangul, Han, and Kana code points are rejected.

- ✅ Good: `SKILL.md`, `references/*.md`, and `templates/rules.yaml` use English prose, comments, and example values.
- ❌ Bad: `templates/rules.yaml` comments written in Korean; `references/eslint.md` contains Hangul characters.
- Exception: `README.ko.md` lives at the repo root (outside `skills/`) and stays Korean under the rule-001 dual-language contract.

Enforcement: `.harness/hooks/check-skill-english.sh` run by the `pre-commit` git hook scans staged Skill files for code points in U+3040–U+30FF (Kana), U+3400–U+9FFF (Han), or U+AC00–U+D7AF (Hangul).
