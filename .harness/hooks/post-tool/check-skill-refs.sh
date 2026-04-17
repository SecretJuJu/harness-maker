#!/usr/bin/env bash
# harness: rule-003
# PostToolUse: when SKILL.md or a references/*.md is edited, re-verify every
# 'references/<name>.md' link in SKILL.md resolves on disk.
set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null)
[ -z "$file_path" ] && exit 0

case "$file_path" in
  */skills/harness-maker/SKILL.md|*/skills/harness-maker/references/*) ;;
  *) exit 0 ;;
esac

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
skill="$root/skills/harness-maker/SKILL.md"
[ -f "$skill" ] || exit 0

fail=0
while IFS= read -r link; do
  [ -z "$link" ] && continue
  target="$root/skills/harness-maker/$link"
  if [ ! -f "$target" ]; then
    echo "harness[rule-003]: SKILL.md references missing file: $link (expected at $target)"
    fail=1
  fi
done < <(grep -oE 'references/[A-Za-z0-9_.-]+\.md' "$skill" | sort -u)

exit $fail
