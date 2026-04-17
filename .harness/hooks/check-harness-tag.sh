#!/usr/bin/env bash
# harness: rule-002
# Verify every staged .claude/rules/*.md carries [Harness: rule-XXX]
# and every staged .harness/hooks/*.sh carries '# harness: rule-XXX'.
set -euo pipefail

staged=$(git diff --cached --name-only --diff-filter=ACMR)
[ -z "$staged" ] && exit 0

fail=0

while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  case "$f" in
    .claude/rules/*.md)
      if ! grep -qE '\[Harness: rule-[0-9]+\]' "$f"; then
        echo "harness[rule-002]: $f missing '[Harness: rule-XXX]' tag in body." >&2
        fail=1
      fi
      ;;
    .harness/hooks/*.sh)
      if ! grep -qE '^# harness: rule-[0-9]+' "$f"; then
        echo "harness[rule-002]: $f missing '# harness: rule-XXX' header comment." >&2
        fail=1
      fi
      ;;
  esac
done <<< "$staged"

exit $fail
