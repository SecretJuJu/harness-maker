# Claude 연동 기반 규칙 강제

## 언제 사용하나

- **Claude가 코드 생성/수정할 때** 따라야 할 규칙 → CLAUDE.md 또는 .claude/rules/
- **Claude Code hook**으로 결정론적(deterministic) 강제 → .claude/settings.json
- 정적 분석으로 잡기 어려운 **의미적/설계적 규칙** → prompt hook 또는 agent hook

## 핵심 구분: 권고 vs 강제

이 구분을 반드시 이해하고 규칙 설계에 반영해야 한다.

- **CLAUDE.md / .claude/rules/*.md = 권고(advisory)**
  Claude가 컨텍스트로 읽지만, 복잡한 작업 중 무시할 수 있다.
  예방 역할. Claude가 "처음부터 규칙대로" 코드를 생성하게 유도한다.

- **Hooks = 결정론적(deterministic)**
  무조건 실행된다. Claude가 건너뛸 수 없다.
  검출/차단 역할. 위반이 발생하면 잡아낸다.

**따라서 중요한 규칙은 hooks로 강제하고, CLAUDE.md는 보조 수단으로 쓴다.**
두 메커니즘을 조합하면: CLAUDE.md로 대부분 예방 + hook으로 놓친 것 검출.

---

## CLAUDE.md / .claude/rules/

### 저장 위치 선택

**방법 1: CLAUDE.md** — 프로젝트 전체에 적용되는 규칙을 모아둘 때

```
project-root/
  CLAUDE.md          ← 프로젝트 전체 규칙
  src/
    CLAUDE.md        ← src/ 하위에만 적용
```

**방법 2: .claude/rules/*.md** — 규칙을 개별 파일로 분리할 때 (권장)

```
project-root/
  .claude/
    rules/
      prefer-function-keyword.md
      conventional-commits.md
      no-default-export.md
```

`.claude/rules/` 방식의 장점:
- 규칙별로 파일이 분리되어 관리하기 쉽다
- 규칙 추가/삭제가 다른 규칙에 영향을 주지 않는다
- git에서 규칙별 변경 이력을 추적하기 좋다
- 하네스가 규칙을 자동으로 추가/삭제하기 쉽다

### 규칙 파일 작성법

```markdown
---
description: TypeScript 파일 수정 시 적용
globs: "src/**/*.ts"
---

# [Harness: rule-001] Function 키워드 선호

TypeScript에서 최상위 함수 선언 시 arrow function 대신 function 키워드를 사용한다.

- ✅ `export function handleClick(e: Event) { ... }`
- ❌ `export const handleClick = (e: Event) => { ... }`
- 예외: 콜백 인자 (예: `arr.map(x => x + 1)`)
```

핵심 원칙:
- frontmatter의 `globs`로 적용 범위를 좁힌다 (해당 파일 수정 시에만 로드됨)
- `[Harness: rule-XXX]` 태그로 하네스 규칙임을 표시
- ✅/❌ 예시를 반드시 포함
- 예외 사항을 명시

---

## Claude Code Hooks

### 개요

Claude Code는 lifecycle 이벤트에 hook을 걸어 자동 실행할 수 있다.
설정은 `.claude/settings.json`에 한다.

### 4가지 handler type

규칙의 성격에 따라 적절한 handler type을 선택한다:

| Type | 용도 | 속도 | 판단력 |
|------|------|------|--------|
| `command` | 결정론적 패턴 매칭, 포맷팅 | 빠름 | 없음 (스크립트 로직만) |
| `prompt` | 의미적 판단이 필요한 규칙 | 보통 (30s timeout) | LLM 단일 턴 판단 |
| `agent` | 코드베이스 탐색이 필요한 검증 | 느림 (60s timeout) | 도구 사용 가능 |
| `http` | 외부 서비스 연동 | 네트워크 의존 | 서버 로직 |

**선택 기준:**
- grep/regex로 잡을 수 있는 패턴 → `command`
- "이 함수명이 충분히 서술적인가?" 같은 판단 → `prompt`
- "수정된 파일에 대응하는 테스트 파일이 있나?" 같은 탐색 → `agent`
- 팀 공유 정책 서버가 있으면 → `http`

### 주요 hook event (규칙 강제에 유용한 것들)

| Event | 시점 | 하네스 활용 |
|-------|------|-----------|
| `PreToolUse` | 도구 실행 전 | **가장 강력** — 작업을 차단할 수 있음 |
| `PostToolUse` | 도구 실행 후 | 자동 포맷팅, 패턴 검사, 피드백 |
| `UserPromptSubmit` | 유저 프롬프트 제출 시 | 컨텍스트 주입, 규칙 리마인더 |
| `SessionStart` | 세션 시작 시 | 환경 변수 설정, 초기 컨텍스트 |
| `Stop` | Claude 응답 완료 시 | 최종 검증 (모든 규칙 충족?) |

### 설정 형식

```json
// .claude/settings.json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": ".harness/hooks/check-style.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(git commit*)",
            "command": ".harness/hooks/check-commit-msg.sh"
          }
        ]
      }
    ]
  }
}
```

### `if` 필드로 정밀 필터링

`matcher`는 도구 이름만 필터링하지만, `if`는 인자까지 필터링한다.
불필요한 hook 실행을 줄여 성능에 도움된다.

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "if": "Bash(git commit*)",
      "command": ".harness/hooks/validate-commit.sh"
    }
  ]
}
```

이렇게 하면 모든 Bash 명령이 아니라 `git commit`으로 시작하는 명령에만 hook이 실행된다.

### command hook 예시: 코드 스타일 검사

```bash
#!/usr/bin/env bash
# .harness/hooks/check-style.sh
# PostToolUse: 파일 수정 후 arrow function 패턴 검사

# hook은 stdin으로 JSON을 받는다
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

[ -z "$FILE_PATH" ] && exit 0
[[ ! "$FILE_PATH" =~ \.(ts|tsx)$ ]] && exit 0

if grep -nE "^(export )?(const|let) \w+ = (\(|async \()" "$FILE_PATH" | head -5; then
  echo "⚠️ [Harness rule-001] Arrow function이 감지되었습니다."
  echo "function 키워드를 사용해주세요."
  exit 2  # PreToolUse에서는 exit 2가 도구 실행 차단, PostToolUse에서는 exit 1이 피드백
fi
exit 0
```

### prompt hook 예시: 의미적 규칙 판단

정적 분석으로 잡을 수 없는 규칙에 LLM 판단을 사용한다.

```json
{
  "matcher": "Edit|Write",
  "hooks": [
    {
      "type": "prompt",
      "prompt": "다음 코드 변경이 프로젝트의 규칙을 준수하는지 확인해주세요. 규칙: 함수명은 동사로 시작해야 하며, 변수명은 그 역할을 명확히 설명해야 합니다. 변경 내용: $ARGUMENTS. 위반이 있으면 ok: false와 reason을 반환하세요."
    }
  ]
}
```

prompt hook의 응답 형식 (모델이 JSON으로 반환):
```json
{ "ok": false, "reason": "함수 'data'는 동사로 시작하지 않습니다. 'fetchData'가 적절합니다." }
```
`"ok": false`이면 차단되고, `reason`이 Claude에게 피드백된다.

prompt hook은 Haiku 모델이 기본이지만, `model` 필드로 변경 가능하다.
비용과 속도를 고려하면 Haiku가 대부분의 규칙 판단에 충분하다.

### agent hook 예시: 코드베이스 탐색

```json
{
  "matcher": "Edit|Write",
  "hooks": [
    {
      "type": "agent",
      "prompt": "수정된 파일에 대응하는 테스트 파일이 존재하는지 확인하세요. src/foo.ts를 수정했다면 tests/foo.test.ts 또는 src/__tests__/foo.test.ts가 있어야 합니다."
    }
  ]
}
```

agent hook은 Read, Grep, Glob 도구를 사용해서 코드베이스를 탐색할 수 있다.
강력하지만 느리므로(60s timeout), 자주 실행되는 이벤트에는 부적합하다.

### async hook: 비차단 실행

로깅, 알림 등 결과를 기다릴 필요 없는 작업에 사용한다.

```json
{
  "type": "command",
  "command": "node .harness/hooks/log-change.js",
  "async": true,
  "timeout": 10
}
```

차단(blocking) hook과 달리 Claude의 작업 흐름을 멈추지 않는다.
단, 차단이 필요한 규칙 검사에는 쓰면 안 된다.

### hook의 exit code

이벤트에 따라 exit code의 의미가 다르다:

**PreToolUse (도구 실행 전):**
- `exit 0` — 통과, 도구 실행 허용
- `exit 2` — 차단, 도구 실행을 막고 stdout 내용을 Claude에게 피드백

**PostToolUse (도구 실행 후):**
- `exit 0` — 통과
- `exit 1` 이상 — 에러로 처리, stdout 내용이 Claude에게 피드백됨

**Stop (응답 완료 시):**
- `exit 0` — 통과, Claude 정지 허용
- `exit 1` 이상 — Claude가 멈추지 않고 피드백 기반으로 계속 작업

### 도구 패밀리 커버 주의

Write를 차단하면 모델이 Bash heredoc으로 우회할 수 있다.
규칙을 강제할 때는 개별 도구가 아닌 관련 도구 그룹을 모두 커버한다:

```json
{
  "matcher": "Edit|Write|MultiEdit|Bash",
  "hooks": [...]
}
```

---

## 고급 패턴

### SessionStart: 하네스 규칙 리마인더 자동 주입

세션 시작 시 활성 규칙을 요약해서 Claude의 컨텍스트에 주입한다.
`.claude/rules/`와 달리 이 방법은 **항상** 로드된다 (파일 수정과 무관).

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": ".harness/hooks/inject-rules-summary.sh"
          }
        ]
      }
    ]
  }
}
```

```bash
#!/usr/bin/env bash
# .harness/hooks/inject-rules-summary.sh
# 활성 규칙 요약을 additionalContext로 주입

RULES_FILE=".harness/rules.yaml"
[ ! -f "$RULES_FILE" ] && exit 0

# YAML 파싱 (python 사용)
SUMMARY=$(python3 -c "
import yaml, sys
with open('$RULES_FILE') as f:
    data = yaml.safe_load(f)
for r in data.get('rules', []):
    print(f\"- [{r['id']}] {r['name']}: {r['description']} (severity: {r['severity']})\")
" 2>/dev/null)
[ -z "$SUMMARY" ] && exit 0

cat <<EOF
{"additionalContext": "## 활성 하네스 규칙\n이 프로젝트에는 다음 코딩 규칙이 설정되어 있습니다:\n${SUMMARY}\n자세한 내용은 .claude/rules/ 또는 .harness/rules.yaml을 참고하세요."}
EOF
```

### Stop: 작업 완료 전 최종 검증

Claude가 응답을 끝내기 전에 모든 하네스 규칙을 충족하는지 확인한다.
위반이 있으면 Claude가 멈추지 않고 수정을 계속한다.

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": ".harness/hooks/final-check.sh"
          }
        ]
      }
    ]
  }
}
```

```bash
#!/usr/bin/env bash
# .harness/hooks/final-check.sh
# 마지막에 수정된 파일들의 하네스 규칙 위반 확인

# 이번 세션에서 수정된 파일 확인
MODIFIED=$(git diff --name-only 2>/dev/null | head -20)
[ -z "$MODIFIED" ] && exit 0

ERRORS=""

for file in $MODIFIED; do
  [[ ! "$file" =~ \.(ts|tsx)$ ]] && continue
  [ ! -f "$file" ] && continue
  # 각 규칙 검사 (예시: arrow function)
  if grep -qE "^(export )?(const|let) \w+ = (\(|async \()" "$file" 2>/dev/null; then
    ERRORS="${ERRORS}\n⚠️ $file: arrow function export 발견"
  fi
done

if [ -n "$ERRORS" ]; then
  echo -e "❌ [Harness] 하네스 규칙 위반이 남아있습니다:${ERRORS}"
  echo "수정해주세요."
  exit 1
fi
exit 0
```

Stop hook은 매 응답마다 실행되므로 가볍게 유지한다.
복잡한 검증은 린트 도구의 캐시(`--cache`)를 활용하거나,
수정된 파일만 대상으로 한다.

---

## 규칙 유형별 추천 조합

| 규칙 유형 | 권고 (예방) | 강제 (검출) |
|-----------|-----------|-----------|
| 코드 스타일 패턴 | .claude/rules/ | command hook (PostToolUse) |
| 커밋 메시지 포맷 | .claude/rules/ | command hook (PreToolUse + if) |
| 네이밍 컨벤션 | .claude/rules/ | prompt hook (PostToolUse) |
| 아키텍처 규칙 | .claude/rules/ | agent hook (PostToolUse) |
| 테스트 파일 필수 | .claude/rules/ | agent hook (Stop) |
| 금지 패턴 (import 등) | .claude/rules/ | command hook (PostToolUse) |

---

## 기존 설정 확인

```bash
# Claude 설정 상태 확인
cat CLAUDE.md 2>/dev/null | head -30
ls .claude/rules/ 2>/dev/null
cat .claude/settings.json 2>/dev/null
find . -name "CLAUDE.md" -maxdepth 3 2>/dev/null
```

기존 CLAUDE.md가 있으면 내용을 보존하고 적절한 위치에 규칙을 추가한다.
기존 hooks 설정이 있으면 이벤트 키 안에 새 matcher를 추가한다 (덮어쓰지 않는다).
