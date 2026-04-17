#!/usr/bin/env bash
# harness: rule-001
# Ensure README.md and README.ko.md are updated together (1:1 bilingual contract).
set -euo pipefail

staged=$(git diff --cached --name-only --diff-filter=ACMR)

en=$(printf '%s\n' "$staged" | grep -x 'README.md' || true)
ko=$(printf '%s\n' "$staged" | grep -x 'README.ko.md' || true)

if [ -n "$en" ] && [ -z "$ko" ]; then
  echo "harness[rule-001]: README.md staged but README.ko.md is not — update both (1:1 bilingual contract)." >&2
  exit 1
fi

if [ -n "$ko" ] && [ -z "$en" ]; then
  echo "harness[rule-001]: README.ko.md staged but README.md is not — update both (1:1 bilingual contract)." >&2
  exit 1
fi

exit 0
