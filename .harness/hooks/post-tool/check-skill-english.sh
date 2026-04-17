#!/usr/bin/env bash
# harness: rule-005
# PostToolUse: the file Claude just wrote under skills/*/{SKILL.md, references,
# templates} must be English outside YAML frontmatter. Catches Hangul/Han/Kana
# immediately so Claude can self-correct before the pre-commit backstop fires.
set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null)
[ -z "$file_path" ] && exit 0
[ -f "$file_path" ] || exit 0

case "$file_path" in
  */skills/*/SKILL.md|*/skills/*/references/*.md|*/skills/*/templates/*) ;;
  *) exit 0 ;;
esac

case "$file_path" in
  *.md)
    hits=$(perl -CSD -ne '
      BEGIN { our $in_fm = 0 }
      if ($. == 1 && /^---\s*$/) { $in_fm = 1; next }
      if ($in_fm && /^---\s*$/) { $in_fm = 0; next }
      next if $in_fm;
      print "  $ARGV:$.: $_" if /[\x{3040}-\x{30FF}\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}\x{AC00}-\x{D7AF}]/
    ' "$file_path")
    ;;
  *)
    hits=$(perl -CSD -ne 'print "  $ARGV:$.: $_" if /[\x{3040}-\x{30FF}\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}\x{AC00}-\x{D7AF}]/' "$file_path")
    ;;
esac

if [ -n "$hits" ]; then
  echo "harness[rule-005]: $file_path contains non-English (Hangul/Han/Kana) — Skill content must be English (frontmatter exempt)."
  printf '%s\n' "$hits"
  exit 1
fi
exit 0
