#!/usr/bin/env bash
# harness: rule-002
# PostToolUse: the file Claude just wrote under .claude/rules/ or
# .harness/hooks/ must carry its harness rule tag.
set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null)
[ -z "$file_path" ] && exit 0
[ -f "$file_path" ] || exit 0

case "$file_path" in
  */.claude/rules/*.md)
    if ! grep -qE '\[Harness: rule-[0-9]+\]' "$file_path"; then
      echo "harness[rule-002]: $file_path is missing '[Harness: rule-XXX]' tag in its body."
      exit 1
    fi
    ;;
  */.harness/hooks/*.sh)
    if ! grep -qE '^# harness: rule-[0-9]+' "$file_path"; then
      echo "harness[rule-002]: $file_path is missing '# harness: rule-XXX' header comment."
      exit 1
    fi
    ;;
esac
exit 0
