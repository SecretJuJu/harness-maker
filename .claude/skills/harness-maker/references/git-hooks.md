# Git Hooks 기반 규칙 강제

## 언제 사용하나

- **커밋 메시지 포맷** 강제 → `commit-msg` hook
- **커밋 전 코드 검사** → `pre-commit` hook
- **푸시 전 테스트 실행** → `pre-push` hook
- **브랜치 네이밍** 강제 → `pre-push` hook

## 사전 확인

```bash
# 기존 hook 시스템 확인
ls -la .husky/ 2>/dev/null          # Husky
ls -la .git/hooks/ 2>/dev/null       # native git hooks
cat package.json | grep -E "husky|lint-staged|lefthook" 2>/dev/null
ls .lefthook* 2>/dev/null           # Lefthook
```

## Husky가 있는 경우 (권장)

이미 Husky를 쓰고 있으면 Husky의 구조를 따른다.

### Husky v9+ (현재 버전)

아래 내용으로 `.husky/commit-msg` 파일을 생성한다:

```bash
#!/usr/bin/env sh
# harness: rule-001 commit-convention
# 커밋 메시지 포맷 검사

commit_msg=$(cat "$1")

# Conventional Commits 포맷 검사
if ! echo "$commit_msg" | grep -qE "^(feat|fix|docs|style|refactor|test|chore|ci|perf|build|revert)(\(.+\))?: .{1,}$"; then
  echo "❌ 커밋 메시지가 Conventional Commits 포맷이 아닙니다."
  echo "   형식: <type>(<scope>): <description>"
  echo "   예시: feat(auth): JWT 토큰 인증 구현"
  echo ""
  echo "   type: feat|fix|docs|style|refactor|test|chore|ci|perf|build|revert"
  exit 1
fi
```

생성 후 `chmod +x .husky/commit-msg` 실행.

### pre-commit hook 예시

아래 내용으로 `.husky/pre-commit` 파일을 생성한다:

```bash
#!/usr/bin/env sh
# harness: 하네스 규칙 pre-commit 검사

# staged 파일 중 대상 파일만 필터링
STAGED_TS=$(git diff --cached --name-only --diff-filter=ACM | grep -E "\.(ts|tsx)$")

if [ -n "$STAGED_TS" ]; then
  # ESLint 검사 (하네스 규칙 포함)
  npx eslint $STAGED_TS
  if [ $? -ne 0 ]; then
    echo "❌ 하네스 규칙 위반이 발견되었습니다. 수정 후 다시 커밋하세요."
    exit 1
  fi
fi
```

생성 후 `chmod +x .husky/pre-commit` 실행.

## Husky가 없는 경우

### 옵션 A: Husky 설치 (권장)

```bash
npm install --save-dev husky
npx husky init
```

이후 위의 Husky 방식을 따른다.

### 옵션 B: Native git hooks

프로젝트에 npm을 안 쓰거나 가볍게 가고 싶을 때.

```bash
mkdir -p .githooks

# git config로 hook 디렉토리 변경
git config core.hooksPath .githooks
```

`.githooks/` 에 hook 스크립트를 넣는다 (위 Husky 예시와 동일한 내용).

팀과 공유하려면 `.githooks/`를 git에 커밋하고,
README나 CLAUDE.md에 `git config core.hooksPath .githooks` 실행 안내를 추가한다.

### 옵션 C: Lefthook

Lefthook을 이미 쓰고 있거나, Husky보다 빠른 대안을 원할 때.

```yaml
# lefthook.yml
commit-msg:
  commands:
    conventional-commits:
      run: |
        commit_msg=$(cat "$1")
        if ! echo "$commit_msg" | grep -qE "^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: .+$"; then
          echo "❌ Conventional Commits 형식이 아닙니다."
          exit 1
        fi

pre-commit:
  commands:
    harness-lint:
      glob: "*.{ts,tsx}"
      run: npx eslint {staged_files}
```

Lefthook은 `{staged_files}` 플레이스홀더를 지원해서
별도 스크립트 없이 staged 파일만 대상으로 검사할 수 있다.

### 옵션 D: pre-commit (Python 생태계)

`.pre-commit-config.yaml`을 이미 쓰고 있는 Python 프로젝트.

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: harness-check
        name: "Harness rule check"
        entry: .harness/hooks/check-all.sh
        language: script
        types: [python]
```

pre-commit 프레임워크는 가상환경 관리를 자동으로 해주므로
Python 프로젝트에서는 Husky보다 이쪽이 자연스럽다.

Ruff 같은 도구를 함께 쓰는 경우:
```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
  - repo: local
    hooks:
      - id: harness-check
        name: Harness custom rules
        entry: .harness/hooks/check-all.sh
        language: script
        types: [python]
```

## 커밋 메시지 규칙 패턴들

### Conventional Commits

```bash
# 패턴
^(feat|fix|docs|style|refactor|test|chore|ci|perf|build|revert)(\(.+\))?(!)?: .{1,}$

# 예시
feat(auth): JWT 토큰 인증 구현
fix: 로그인 페이지 크래시 수정
docs(readme): 설치 가이드 업데이트
```

### Jira 이슈 번호 포함

```bash
# 패턴: [PROJECT-123] 메시지
^\\[([A-Z]+-[0-9]+)\\] .{1,}$

# 또는: PROJECT-123: 메시지
^[A-Z]+-[0-9]+: .{1,}$
```

### 커스텀 포맷

유저가 독자적인 포맷을 원하면, 해당 정규식을 파악해서 commit-msg hook에 넣는다.

## lint-staged 연동

pre-commit에서 staged 파일만 검사할 때 lint-staged를 활용하면 편하다.

```bash
npm install --save-dev lint-staged
```

```json
// package.json
{
  "lint-staged": {
    "*.{ts,tsx}": [
      "eslint --fix",
      "prettier --write"
    ]
  }
}
```

```bash
# .husky/pre-commit
#!/usr/bin/env sh
npx lint-staged
```

## 주의사항

- hook 스크립트에 `# harness: rule-XXX` 주석을 달아서 어떤 하네스 규칙인지 추적 가능하게 한다.
- 기존 hook이 있으면 **덮어쓰지 말고** 기존 내용 뒤에 추가한다.
- `exit 1`로 커밋/푸시를 차단하는 건 `severity: error`인 규칙만. `warn`이면 경고만 출력하고 통과시킨다.
- hook 파일에 실행 권한(`chmod +x`)을 반드시 부여한다.

---

## 관련 레퍼런스

- staged 파일만 검사, early exit 등 성능 최적화 → `performance.md`
- 같은 스크립트를 git hook과 Claude Code hook에서 공유 → `custom-scripts.md`의 "양쪽 호환 패턴"
