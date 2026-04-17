#!/usr/bin/env bash
# harness: rule-003
# Ensure every 'references/*.md' link mentioned in SKILL.md resolves
# to a file under skills/harness-maker/references/.
set -euo pipefail

staged=$(git diff --cached --name-only --diff-filter=ACMR)

# Early exit: only run when SKILL.md or references/ is touched.
if ! printf '%s\n' "$staged" | grep -qE '(^|/)SKILL\.md$|/references/'; then
  exit 0
fi

skill="skills/harness-maker/SKILL.md"
[ -f "$skill" ] || exit 0

fail=0
# Extract every 'references/<name>.md' mention from SKILL.md (dedup).
while IFS= read -r link; do
  [ -z "$link" ] && continue
  target="skills/harness-maker/$link"
  if [ ! -f "$target" ]; then
    echo "harness[rule-003]: SKILL.md references missing file: $link (expected at $target)" >&2
    fail=1
  fi
done < <(grep -oE 'references/[A-Za-z0-9_.-]+\.md' "$skill" | sort -u)

exit $fail
