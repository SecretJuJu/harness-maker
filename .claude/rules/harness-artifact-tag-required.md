---
description: Generated artifacts must carry their originating rule id so the harness can trace them back.
globs: ".claude/rules/*.md,.harness/hooks/*.sh"
---

# [Harness: rule-002] harness-artifact-tag-required

Every harness-generated artifact must include its originating rule id. The tag lets the harness trace artifacts back to rules for updates, deletion, and audits.

- ✅ Good: A `.claude/rules/*.md` body contains `[Harness: rule-042]`. A `.harness/hooks/check-foo.sh` starts with `# harness: rule-042`.
- ❌ Bad: A rule file without the tag; a hook script missing the header comment — the artifact is orphaned from its declaration.
- Exception: None. The tag is the traceability contract.

Form by file type:
- Markdown (`.claude/rules/*.md`): `[Harness: rule-XXX]` somewhere in the body.
- Shell hook scripts (`.harness/hooks/*.sh`): `# harness: rule-XXX` as a header comment near the top.

Enforcement: `.harness/hooks/check-harness-tag.sh` run by the `pre-commit` git hook rejects artifacts missing the tag.
