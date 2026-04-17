#!/usr/bin/env bash
# harness: rule-006
# Non-blocking nudge: when skills/** is staged without README.md or
# README.ko.md, remind the committer to check whether the READMEs need
# updating. Always exits 0 — advisory only, since whether a README edit is
# warranted requires human judgment.
set -euo pipefail

staged=$(git diff --cached --name-only --diff-filter=ACMR)
[ -z "$staged" ] && exit 0

skills_changed=$(printf '%s\n' "$staged" | grep -E '^skills/' || true)
[ -z "$skills_changed" ] && exit 0

readme_changed=$(printf '%s\n' "$staged" | grep -E '^README(\.ko)?\.md$' || true)
[ -n "$readme_changed" ] && exit 0

{
  echo "harness[rule-006]: skills/** changed but neither README.md nor README.ko.md is staged."
  echo "  Check whether the change is user-facing (install steps, Skill list, trigger phrases, behavior)."
  echo "  If yes, update both READMEs (rule-001 dual-language contract applies)."
  echo "  If no (pure internal refactor), this warning is safe to ignore."
} >&2
exit 0
