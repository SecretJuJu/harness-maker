# 커스텀 린트 스크립트 기반 규칙 강제

## 언제 사용하나

- ESLint 등 기존 도구로 표현하기 어려운 **프로젝트 고유 규칙**
- **파일 구조/디렉토리 규칙** (예: feature 폴더에는 반드시 index.ts가 있어야 함)
- **파일 간 관계 규칙** (예: 각 컴포넌트에 대응하는 테스트 파일 필수)
- **복잡한 패턴 매칭** (여러 파일에 걸친 규칙)
- **비코드 파일 규칙** (README 필수, 특정 설정 파일 존재 여부 등)
- **린트 도구 레퍼런스가 없는 언어** — Biome, Ruff 등의 레퍼런스가 없는
  언어/도구 조합에서는 커스텀 스크립트가 주요 강제 수단이 될 수 있다.
  예: 특정 언어의 코딩 컨벤션을 grep/awk로 검사하는 방식.

## 스크립트 위치

```
.harness/
  hooks/
    check-<rule-name>.sh    # 개별 규칙 스크립트
    check-all.sh             # 전체 규칙 실행기
```

`hooks/` 디렉토리 하나에 모든 스크립트를 둔다.
같은 스크립트를 Claude Code hook과 git hook 양쪽에서 참조할 수 있다.

## 스크립트 템플릿

### Bash 스크립트 (단순 패턴)

```bash
#!/usr/bin/env bash
# .harness/hooks/check-no-arrow-exports.sh
# Harness rule-001: export된 arrow function 감지
set -euo pipefail

ERRORS=0
TARGET_GLOB="${1:-src/**/*.ts}"

for file in $(find src -name "*.ts" -o -name "*.tsx" 2>/dev/null); do
  # export const xxx = (...) => 패턴 검출
  matches=$(grep -nE "^export (const|let) \w+ = (\(|async \()" "$file" 2>/dev/null || true)
  if [ -n "$matches" ]; then
    echo "⚠️  $file:"
    echo "$matches" | while read -r line; do
      echo "   $line"
    done
    ERRORS=$((ERRORS + 1))
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "❌ ${ERRORS}개 파일에서 arrow function export가 발견되었습니다."
  echo "   function 키워드를 사용해주세요: export function xxx() { ... }"
  exit 1
else
  echo "✅ Arrow function export 규칙 통과"
  exit 0
fi
```

### Node.js 스크립트 (복잡한 로직)

```javascript
#!/usr/bin/env node
// .harness/hooks/check-feature-structure.js
// Harness rule-005: feature 디렉토리 구조 규칙

const fs = require("fs");
const path = require("path");

const FEATURES_DIR = "src/features";
const REQUIRED_FILES = ["index.ts", "types.ts"];

let errors = 0;

if (!fs.existsSync(FEATURES_DIR)) {
  console.log("✅ features 디렉토리가 없으므로 스킵");
  process.exit(0);
}

const features = fs.readdirSync(FEATURES_DIR, { withFileTypes: true })
  .filter(d => d.isDirectory())
  .map(d => d.name);

for (const feature of features) {
  const featurePath = path.join(FEATURES_DIR, feature);
  for (const required of REQUIRED_FILES) {
    const filePath = path.join(featurePath, required);
    if (!fs.existsSync(filePath)) {
      console.log(`⚠️  ${featurePath}/ 에 ${required}가 없습니다.`);
      errors++;
    }
  }
}

if (errors > 0) {
  console.log(`\n❌ ${errors}개 위반 발견. 각 feature 폴더에는 ${REQUIRED_FILES.join(", ")}이 필요합니다.`);
  process.exit(1);
} else {
  console.log("✅ Feature 구조 규칙 통과");
  process.exit(0);
}
```

## 전체 규칙 실행기

모든 하네스 스크립트를 한 번에 실행하는 러너.

```bash
#!/usr/bin/env bash
# .harness/hooks/check-all.sh
# 모든 하네스 커스텀 규칙 실행
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAIL=0

echo "🔍 하네스 규칙 검사 시작..."
echo ""

for script in "$SCRIPT_DIR"/check-*.sh; do
  [ "$script" = "$SCRIPT_DIR/check-all.sh" ] && continue
  [ ! -x "$script" ] && continue

  RULE_NAME=$(basename "$script" .sh | sed 's/^check-//')
  echo "━━━ $RULE_NAME ━━━"

  if ! bash "$script"; then
    FAIL=$((FAIL + 1))
  fi
  echo ""
done

# Node.js 스크립트도 실행
for script in "$SCRIPT_DIR"/check-*.js; do
  [ ! -f "$script" ] && continue

  RULE_NAME=$(basename "$script" .js | sed 's/^check-//')
  echo "━━━ $RULE_NAME ━━━"

  if ! node "$script"; then
    FAIL=$((FAIL + 1))
  fi
  echo ""
done

if [ $FAIL -gt 0 ]; then
  echo "❌ ${FAIL}개 규칙 위반 발견"
  exit 1
else
  echo "✅ 모든 하네스 규칙 통과"
  exit 0
fi
```

## git hook과 연동

커스텀 스크립트를 pre-commit hook에서 실행:

```bash
# .husky/pre-commit (또는 .githooks/pre-commit)
#!/usr/bin/env sh

# 하네스 커스텀 규칙 검사
if [ -x .harness/hooks/check-all.sh ]; then
  .harness/hooks/check-all.sh
fi
```

## 스크립트 작성 원칙

- **exit code**: 0=통과, 1=실패
- **출력**: 위반 파일과 줄 번호를 명확히 표시
- **성능**: staged 파일만 대상으로 하는 옵션 제공 (인자로 파일 목록 받기)
- **실행 권한**: `chmod +x` 필수
- **주석**: 스크립트 상단에 `# harness: rule-XXX` 형태로 어떤 규칙인지 표기
- **멱등성**: 여러 번 실행해도 같은 결과

## Claude Code hook에서 커스텀 스크립트 사용

같은 스크립트를 git hook과 Claude Code hook 양쪽에서 쓸 수 있게 만들면 좋다.
차이점은 Claude Code hook은 **stdin으로 JSON**을 받고, git hook은 **인자나 환경변수**를 받는다는 것.

### 양쪽 호환 패턴

```bash
#!/usr/bin/env bash
# .harness/hooks/check-no-arrow-exports.sh
# harness: rule-001
# 사용: git hook에서 직접 실행 또는 Claude Code hook에서 stdin JSON으로 호출

# Claude Code hook 컨텍스트인지 판별
if [ -t 0 ]; then
  # stdin이 터미널 → git hook이나 수동 실행
  # 인자로 파일을 받거나 staged 파일 사용
  FILES="${@:-$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(ts|tsx)$')}"
else
  # stdin이 파이프 → Claude Code hook
  INPUT=$(cat)
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
  [ -z "$FILE_PATH" ] && exit 0
  FILES="$FILE_PATH"
fi

[ -z "$FILES" ] && exit 0

ERRORS=0
for file in $FILES; do
  [[ ! "$file" =~ \.(ts|tsx)$ ]] && continue
  [ ! -f "$file" ] && continue
  matches=$(grep -nE "^export (const|let) \w+ = (\(|async \()" "$file" 2>/dev/null || true)
  if [ -n "$matches" ]; then
    echo "⚠️  $file:"
    echo "$matches"
    ERRORS=$((ERRORS + 1))
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo "❌ Arrow function export 발견. function 키워드를 사용하세요."
  exit 1
fi
exit 0
```

이 스크립트를 `.claude/settings.json`과 git hook 양쪽에서 참조할 수 있다:

```json
// .claude/settings.json
{ "hooks": { "PostToolUse": [{ "matcher": "Edit|Write", "hooks": [
  { "type": "command", "command": ".harness/hooks/check-no-arrow-exports.sh" }
]}]}}
```

```bash
# .husky/pre-commit
.harness/hooks/check-no-arrow-exports.sh
```
