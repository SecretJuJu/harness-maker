#!/usr/bin/env bash
# harness: rule-001
# PostToolUse: when Claude edits one README, remind to update the other.
# Fires only if the *other* README is not also modified vs HEAD.
set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null)
[ -z "$file_path" ] && exit 0

base=$(basename "$file_path")
case "$base" in
  README.md) other="README.ko.md" ;;
  README.ko.md) other="README.md" ;;
  *) exit 0 ;;
esac

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
# Scope: only fire for the repo-root READMEs, not nested READMEs inside subprojects.
case "$file_path" in
  "$root/README.md"|"$root/README.ko.md") ;;
  *) exit 0 ;;
esac

modified=$(git -C "$root" diff --name-only HEAD 2>/dev/null || true)
if printf '%s\n' "$modified" | grep -qFx "$other"; then
  exit 0
fi

echo "harness[rule-001]: you edited $base — $other must be updated in the same change (dual-language contract)."
exit 1
