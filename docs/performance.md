# 성능 고려사항

## 왜 중요한가

pre-commit hook이 5초 걸리면 개발자가 `--no-verify`를 습관적으로 쓰게 되고,
규칙이 무력화된다. 강제 메커니즘은 빨라야 지켜진다.

**목표 기준:**
- pre-commit hook: **2초 이내** (staged 파일만 대상)
- commit-msg hook: **0.5초 이내** (문자열 검사이므로)
- pre-push hook: **10초 이내** (테스트 포함 가능)
- Claude Code hook: **1초 이내** (매 도구 호출마다 실행됨)

---

## 핵심 원칙: 변경된 것만 검사한다

### Git hook에서 staged 파일만 대상으로

```bash
# ❌ 느림: 전체 프로젝트 린트
npx eslint .

# ✅ 빠름: staged 파일만
STAGED=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|tsx)$')
[ -z "$STAGED" ] && exit 0
npx eslint $STAGED
```

`--diff-filter=ACM`은 Added, Copied, Modified 파일만 대상으로 한다.
Deleted 파일을 린트하면 "파일 없음" 에러가 난다.

### lint-staged 활용

lint-staged는 staged 파일 필터링을 자동으로 해주고,
부분 스테이징(hunk staging)도 올바르게 처리한다.

```json
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix --max-warnings 0"],
    "*.{ts,tsx,json,md}": ["prettier --write"]
  }
}
```

lint-staged가 이미 있으면 이걸 활용하고, 없으면 도입을 제안하되
간단한 규칙이면 직접 `git diff --cached`로 처리해도 충분하다.

---

## 메커니즘별 성능 팁

### ESLint / Biome

```bash
# ESLint: --cache 옵션으로 변경된 파일만 재검사
npx eslint --cache --cache-location .eslintcache .

# Biome: 기본적으로 빠르지만, 범위를 좁히면 더 빠름
npx biome check src/changed-file.ts
```

ESLint `--cache`는 파일 해시 기반으로 변경되지 않은 파일을 건너뛴다.
`.eslintcache`를 `.gitignore`에 추가해야 한다.

Biome은 ESLint 대비 10-100배 빠르므로 성능 이슈가 드물다.
그래도 전체 프로젝트보다는 대상 파일만 넘기는 것이 좋다.

### Git hooks

```bash
# 대상 파일이 없으면 즉시 종료 (early exit)
STAGED_TS=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|tsx)$')
if [ -z "$STAGED_TS" ]; then
  exit 0  # 검사할 파일이 없으면 바로 통과
fi
```

early exit는 모든 hook 스크립트의 첫 번째 줄에 넣는다.
관련 없는 파일만 커밋할 때 불필요한 실행을 방지한다.

### Claude Code hooks

Claude Code hook은 **매 도구 호출마다** 실행될 수 있으므로 특히 가볍게 만든다.

**handler type별 성능 특성:**

| Type | 기본 timeout | 비용 | 사용 기준 |
|------|------------|------|----------|
| `command` | 없음 (빠름) | 무료 | 패턴 매칭, 포맷팅 |
| `prompt` | 30초 | LLM 호출 비용 | 의미적 판단 (최소화) |
| `agent` | 60초 | LLM + 도구 비용 | 코드베이스 탐색 (드물게) |
| `http` | 네트워크 의존 | 서버 비용 | 외부 정책 서버 |

`prompt`/`agent` hook은 **매 도구 호출마다 LLM을 호출**하므로
PostToolUse 같은 빈번한 이벤트에 쓰면 비용과 지연이 급증한다.
가능하면 `command`로 해결하고, 정말 LLM 판단이 필요한 경우에만 `prompt`를 쓴다.

**`if` 필드로 불필요한 실행 방지:**
```json
{
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "if": "Bash(git commit*)",
    "command": ".harness/hooks/check-commit.sh"
  }]
}
```
`if`가 없으면 모든 Bash 명령에 hook이 실행된다.
`if`가 있으면 패턴 매칭 후 해당하는 경우에만 hook 프로세스가 생성된다.

**command hook 최적화:**
```bash
# ❌ 느림: 매번 npx로 도구 실행
npx eslint "$FILE_PATH"

# ✅ 빠름: grep/awk 같은 가벼운 검사
grep -nE "^export const \w+ = \(.*\) =>" "$FILE_PATH"

# ✅ 빠름: stdin에서 JSON 읽고 파일 확장자 체크 후 early exit
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
[[ ! "$FILE_PATH" =~ \.(ts|tsx)$ ]] && exit 0
```

command hook에서는:
- 무거운 도구(eslint, tsc) 실행을 피한다
- `grep`, `awk`, `sed` 같은 경량 도구를 사용한다
- jq로 stdin에서 JSON을 파싱한다 (인자가 아닌 stdin으로 입력됨)
- 대상 파일이 아니면 즉시 `exit 0`
- 비차단 작업(로깅 등)은 `"async": true`로 백그라운드 실행

### 커스텀 스크립트

```bash
# ❌ 느림: find로 매번 전체 탐색
find src -name "*.ts" | while read f; do
  grep -l "pattern" "$f"
done

# ✅ 빠름: git ls-files 또는 staged 파일 기반
git diff --cached --name-only --diff-filter=ACM | grep '\.ts$' | while read f; do
  grep -l "pattern" "$f"
done

# ✅ 빠름: grep -r로 한 번에 (find + grep 루프 대체)
grep -rnE "pattern" src/ --include="*.ts"
```

---

## 병렬 실행

여러 규칙을 검사할 때 순차 실행하면 시간이 누적된다.

```bash
# ❌ 순차: 각 2초 × 3개 = 6초
bash .harness/hooks/check-rule-001.sh
bash .harness/hooks/check-rule-002.sh
bash .harness/hooks/check-rule-003.sh

# ✅ 병렬: 가장 느린 것 = ~2초
bash .harness/hooks/check-rule-001.sh &
bash .harness/hooks/check-rule-002.sh &
bash .harness/hooks/check-rule-003.sh &
wait
```

단, 병렬 실행 시 출력이 섞이므로, 각 스크립트의 출력을 임시 파일에
저장하고 마지막에 합치는 방법을 쓸 수 있다:

```bash
TMPDIR=$(mktemp -d)
PIDS=()
SCRIPTS=()

for script in .harness/hooks/check-*.sh; do
  [ "$script" = ".harness/hooks/check-all.sh" ] && continue
  bash "$script" > "$TMPDIR/$(basename $script).out" 2>&1 &
  PIDS+=($!)
  SCRIPTS+=("$script")
done

FAIL=0
for i in "${!PIDS[@]}"; do
  if ! wait "${PIDS[$i]}"; then
    FAIL=$((FAIL + 1))
  fi
  cat "$TMPDIR/$(basename ${SCRIPTS[$i]}).out"
done

rm -rf "$TMPDIR"
[ $FAIL -gt 0 ] && exit 1 || exit 0
```

---

## .gitignore에 추가할 것들

하네스가 생성하는 캐시/임시 파일:

```gitignore
# Harness
.eslintcache
```

`.harness/` 디렉토리 자체는 커밋한다 (규칙 공유를 위해).

---

## 성능 측정

규칙을 추가한 뒤 hook이 얼마나 걸리는지 측정해보는 것을 권장한다:

```bash
# git hook 성능 측정
time git commit --allow-empty -m "test: hook 성능 측정"

# 개별 하네스 스크립트 성능 측정
time .harness/hooks/check-no-arrow-exports.sh src/example.ts

# Claude Code hook은 직접 측정이 어려우므로 스크립트만 테스트
echo '{"tool_input":{"file_path":"src/example.ts"}}' | time .harness/hooks/check-style.sh
```

목표 시간을 초과하면 원인을 파악하고 최적화한다.
흔한 원인: npx 콜드 스타트 (~2초), 전체 파일 탐색, 불필요한 도구 실행.

---

## prompt/agent hook 비용 인식

prompt/agent hook은 매 실행마다 LLM API를 호출한다.
빈번한 이벤트에 걸면 비용이 빠르게 누적된다.

**비용 추정 예시 (Haiku 기준):**
- PostToolUse에 prompt hook → 파일 수정 1회당 ~1회 호출
- 10개 파일 수정하는 작업 → ~10회 호출
- 하루 100개 파일 수정 → ~100회 호출

**비용 절약 전략:**
- `if` 필드로 실행 범위를 최대한 좁힌다
- 가능하면 `command` hook(무료)으로 1차 필터링 후, 통과한 것만 `prompt`로 판단
- `agent` hook은 Stop 이벤트처럼 드물게 발생하는 곳에만 사용
- 단순 패턴 매칭은 절대 prompt/agent로 하지 않는다 — grep이면 충분
