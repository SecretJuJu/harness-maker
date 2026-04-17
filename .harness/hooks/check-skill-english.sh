#!/usr/bin/env bash
# harness: rule-005
# Reject Hangul/Han/Kana code points in Skill content.
# Scope:  skills/*/SKILL.md, skills/*/references/*.md, skills/*/templates/*
# Exempt: YAML frontmatter in .md files (leading '---' fenced block) — it holds
#         trigger phrases matched by the Claude Code skill dispatcher, which
#         benefit from being multilingual.
set -euo pipefail

staged=$(git diff --cached --name-only --diff-filter=ACMR)
[ -z "$staged" ] && exit 0

targets=$(printf '%s\n' "$staged" \
  | grep -E '^skills/[^/]+/(SKILL\.md$|references/[^/]+\.md$|templates/[^/]+$)' \
  || true)
[ -z "$targets" ] && exit 0

fail=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  case "$f" in
    *.md)
      hits=$(perl -CSD -ne '
        BEGIN { our $in_fm = 0 }
        if ($. == 1 && /^---\s*$/) { $in_fm = 1; next }
        if ($in_fm && /^---\s*$/) { $in_fm = 0; next }
        next if $in_fm;
        print "  $ARGV:$.: $_" if /[\x{3040}-\x{30FF}\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}\x{AC00}-\x{D7AF}]/
      ' "$f")
      ;;
    *)
      hits=$(perl -CSD -ne 'print "  $ARGV:$.: $_" if /[\x{3040}-\x{30FF}\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}\x{AC00}-\x{D7AF}]/' "$f")
      ;;
  esac
  if [ -n "$hits" ]; then
    {
      echo "harness[rule-005]: $f contains non-English (Hangul/Han/Kana) characters — Skill content must be English-only (frontmatter exempt)."
      printf '%s\n' "$hits"
    } >&2
    fail=1
  fi
done <<< "$targets"

exit $fail
