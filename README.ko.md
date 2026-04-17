[English](./README.md) | **한국어**

# Harness

코드베이스의 규칙을 선언적으로 정의하고, 작업환경에 자동 구성하는 시스템.

## 사용법

LLM 에이전트(Claude Code, Cursor, Copilot 등)에 이 프롬프트를 붙여넣으세요:

```
이 문서를 읽고 내 프로젝트에 하네스를 세팅해줘:
https://raw.githubusercontent.com/{owner}/harness-maker/main/README.md
```

---

## LLM 에이전트를 위한 안내

> 아래 내용은 이 문서를 읽는 LLM 에이전트를 위한 것입니다.
> 유저의 프로젝트에 하네스를 세팅하는 절차를 설명합니다.

### 하네스란

`.harness/rules.yaml`에 코딩 규칙을 **선언**하면,
그 규칙을 프로젝트 환경에 맞게 **자동 구성**하는 시스템입니다.

```
.harness/rules.yaml  →  에이전트가 읽고  →  린트 설정, git hooks,
(선언: what)              환경 구성          .claude/rules/ 등 생성
                                            (구현: how)
```

### 세팅 절차

#### 1. 프로젝트 환경 파악

먼저 유저의 프로젝트를 분석합니다:

```bash
# 프로젝트 루트 확인
ls -la

# 언어 & 패키지 매니저
ls package.json Cargo.toml pyproject.toml go.mod 2>/dev/null
ls package-lock.json yarn.lock pnpm-lock.yaml bun.lockb 2>/dev/null

# 린터/포맷터
ls .eslintrc* eslint.config.* biome.json .prettierrc* deno.json 2>/dev/null
ls .ruff.toml ruff.toml clippy.toml .golangci.yml 2>/dev/null

# Hook 시스템
ls -la .husky/ .githooks/ .lefthook* .pre-commit-config.yaml 2>/dev/null

# Claude 설정
ls CLAUDE.md .claude/ 2>/dev/null

# 기존 하네스
cat .harness/rules.yaml 2>/dev/null
```

#### 2. `.harness/rules.yaml` 생성

프로젝트 루트에 `.harness/` 디렉토리와 `rules.yaml`을 만듭니다.

```bash
mkdir -p .harness
```

`rules.yaml`의 스키마는 다음과 같습니다:

```yaml
rules:
  - id: rule-001
    name: 규칙-이름           # kebab-case
    description: "규칙 설명"
    severity: warn             # warn | error
    scope:
      languages: [typescript]  # 대상 언어 (선택)
      glob: "src/**/*.ts"      # 대상 파일 패턴 (선택)
      trigger: commit          # code | commit | push (선택)
    pattern: '정규식'          # 문자열 매칭 규칙용 (선택)
    examples:
      good: "좋은 예시 코드"
      bad: "나쁜 예시 코드"
    exceptions: "예외 설명"    # 선택
    check: ".harness/hooks/스크립트.sh"  # 커스텀 검사 스크립트 (선택)
```

**유저에게 어떤 규칙을 원하는지 물어보세요.**
프로젝트 환경을 바탕으로 유용할 만한 규칙을 제안해도 좋습니다.

일반적으로 유용한 규칙 예시:
- 커밋 메시지 형식 (Conventional Commits 등)
- import 경로 규칙 (상대경로 금지, 패키지명 사용 등)
- 코드 스타일 (함수 선언 방식, default export 금지 등)
- 아키텍처 규칙 (레이어 간 의존성 방향 등)

#### 3. 규칙별 강제 메커니즘 구성

`rules.yaml`의 각 규칙에 대해, 프로젝트 환경에 맞는 강제 방법을 선택하고 설정합니다.

**메커니즘 선택 기준:**

| 질문 | 메커니즘 |
|------|---------|
| 정적 분석으로 잡히나? | 프로젝트의 린트 도구 (ESLint, Biome, Ruff, Clippy 등) |
| 커밋/푸시 시점에만 관련? | git hook (Husky, Lefthook, native, pre-commit 등) |
| LLM 판단이 필요한 의미적 규칙? | Claude Code `prompt` hook |
| 코드베이스 탐색이 필요? | Claude Code `agent` hook |
| Claude가 코드 생성 시 알아야? | `.claude/rules/` 파일 |

**중요:** 하나의 규칙에 여러 메커니즘을 조합하는 것이 일반적입니다.
- `.claude/rules/` = **권고** (Claude가 무시할 수 있음)
- 린트 도구, git hook, Claude Code hook = **강제** (건너뛸 수 없음)

**기존 도구를 우선 활용합니다.**
프로젝트에 ESLint가 있으면 ESLint에, Biome이 있으면 Biome에 규칙을 추가합니다.
새 도구 도입은 유저 동의 후에만.

**기존 설정을 덮어쓰지 않습니다.**
기존 내용 뒤에 추가하거나, 기존 패턴에 맞게 수정합니다.

각 메커니즘의 구체적인 구현 방법은 `docs/` 디렉토리를 참고하세요:
- `docs/eslint.md` — ESLint flat config/legacy, no-restricted-syntax, 커스텀 룰
- `docs/git-hooks.md` — Husky, Lefthook, native hooks, pre-commit(Python)
- `docs/claude-integration.md` — .claude/rules/, Claude Code hooks (4가지 handler type)
- `docs/custom-scripts.md` — 커스텀 검사 스크립트, git hook / Claude Code hook 양쪽 호환 패턴
- `docs/performance.md` — hook 성능 기준, handler type별 비용, 최적화 패턴

#### 4. `.claude/rules/` 파일 생성

각 규칙에 대해 Claude용 규칙 파일을 생성합니다.
`rules.yaml`의 `examples`, `exceptions` 필드를 활용합니다.

```markdown
<!-- .claude/rules/규칙이름.md -->
---
description: 규칙 설명
globs: "src/**/*.ts"
---

# [Harness: rule-001] 규칙 이름
규칙 설명.

- ✅ 좋은 예: `좋은 예시 코드`
- ❌ 나쁜 예: `나쁜 예시 코드`
- 예외: 예외 설명
```

#### 5. 위반 스캔 및 보고

설정 완료 후, 현재 코드에서 위반 사항을 검사합니다.

위반이 많으면 유저에게 선택지를 제시합니다:
- 자동 수정 가능한 것들은 `--fix`로 일괄 수정
- severity를 `warn`으로 시작해서 점진적으로 수정
- scope를 좁혀서 새 코드부터 적용

#### 6. 유저에게 결과 보고

완료 후 다음을 알려줍니다:
- 추가된 규칙 목록
- 각 규칙이 어떤 메커니즘으로 강제되는지
- 현재 코드의 위반 수 (있으면)
- `.harness/`를 git에 커밋하라는 안내

---

### 이후 유저 요청 대응

| 유저 요청 | 행동 |
|-----------|------|
| "하네스에 규칙 추가해: ..." | `rules.yaml`에 규칙 추가 → 강제 메커니즘 구성 → 스캔 |
| "하네스 구성해줘" | `rules.yaml` 읽고 → 환경 파악 → 전체 구성 재생성 |
| "하네스 규칙 보여줘" | `rules.yaml` 읽어서 보기 좋게 출력 |
| "하네스 체크해" | 모든 활성 규칙의 위반 스캔 실행 |
| "rule-003 삭제해" | `rules.yaml`에서 제거 + 관련 설정 정리 |
| "rule-001 severity error로" | `rules.yaml` 수정 + 관련 설정 반영 |

### 성능 기준

hook이나 스크립트를 만들 때 이 기준을 지킵니다:
- pre-commit hook: 2초 이내
- commit-msg hook: 0.5초 이내
- Claude Code command hook: 1초 이내
- staged 파일만 검사, early exit, 경량 도구 사용

자세한 성능 최적화 방법은 `docs/performance.md`를 참고하세요.
