#!/usr/bin/env bash
# harness: rule-004
# Enforce Conventional Commits on commit-msg: 'type(scope)?: subject'.
set -euo pipefail

msg_file=${1:-}
[ -n "$msg_file" ] && [ -f "$msg_file" ] || exit 0

first_line=$(head -n 1 "$msg_file")

# Skip git-managed auto-messages.
case "$first_line" in
  Merge*|Revert*|'fixup!'*|'squash!'*) exit 0 ;;
esac

pattern='^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\([^)]+\))?!?: .+'
if ! printf '%s' "$first_line" | grep -qE "$pattern"; then
  {
    echo "harness[rule-004]: commit message must follow Conventional Commits."
    echo "  format: type(scope)?: subject"
    echo "  types:  feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert"
    echo "  got:    $first_line"
  } >&2
  exit 1
fi

exit 0
