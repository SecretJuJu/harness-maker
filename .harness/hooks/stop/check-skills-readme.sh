#!/usr/bin/env bash
# harness: rule-006
# Stop hook: at turn end, if the working tree has skills/** changes but neither
# README is touched, remind the maintainer to decide on a README update.
# Exits 0 always — advisory only, does not block Claude from stopping.
set -euo pipefail

changed=$(git status --porcelain 2>/dev/null) || exit 0
[ -z "$changed" ] && exit 0

skills_changed=$(printf '%s\n' "$changed" | grep -E '^.. skills/' || true)
[ -z "$skills_changed" ] && exit 0

readme_changed=$(printf '%s\n' "$changed" | grep -E '^.. README(\.ko)?\.md$' || true)
[ -n "$readme_changed" ] && exit 0

{
  echo "harness[rule-006]: skills/** has uncommitted changes but README.md and README.ko.md are unmodified."
  echo "  Before stopping, evaluate whether the change is user-facing (install steps, Skill list, trigger phrases, behavior)."
  echo "  If yes, update both READMEs (rule-001 dual-language contract)."
  echo "  If it is a pure internal refactor, stopping as-is is fine."
} >&2
exit 0
