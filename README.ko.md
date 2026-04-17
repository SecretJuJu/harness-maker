[English](./README.md) | **한국어**

# Harness

Harness는 한 쌍의 Claude Code Skill로, `.harness/rules.yaml`을 통해 선언적으로 코드베이스 규칙을 관리하고 린트 도구, git 후크, Claude Code 후크를 자동으로 구성하여 규칙을 적용합니다.

- **`harness-maker`** — harness를 구성하거나 발전시키는 메인테이너용 (규칙 추가, 강제 메커니즘 연결, 위반 스캔).
- **`apply-harness`** — 레포를 clone 한 뒤 로컬 머신에서 공유 harness를 활성화해야 하는 기여자용 (git 후크는 per-clone 상태이며 레포와 함께 따라오지 않습니다).

## 설치

이 섹션은 Harness Skill을 설치하는 데 도움이 되도록 이 문서를 읽는 LLM 에이전트를 위한 것입니다.

설치하기 전 **사용자에게 질문하세요**: 이 Skill들을 현재 프로젝트에만 설치해야 합니까(프로젝트 루트 기준 `.claude/skills/`로 범위 지정) 아니면 모든 프로젝트를 위해 전역으로 설치해야 합니까(`~/.claude/skills/`)?

**우선순위:** 같은 Skill 이름이 양쪽에 존재하면 Personal(`~/.claude/skills/`)이 Project보다 우선합니다.

**두 Skill은 함께 설치하세요** — 기여자는 `apply-harness`가, 메인테이너는 둘 다 필요합니다.

### 프로젝트 범위 설치

```bash
mkdir -p .claude/skills
cp -r /path/to/cloned/harness-maker/skills/harness-maker .claude/skills/
cp -r /path/to/cloned/harness-maker/skills/apply-harness .claude/skills/
```

복사 후 Skill들은 다음 Claude Code 세션에서 자동으로 로드됩니다. 메인테이너는 "set up harness", "하네스 설정해줘"로 호출합니다. 기여자는 "apply harness", "하네스 적용"으로 호출합니다.

### 개인/전역 설치

```bash
mkdir -p ~/.claude/skills
cp -r /path/to/cloned/harness-maker/skills/harness-maker ~/.claude/skills/
cp -r /path/to/cloned/harness-maker/skills/apply-harness ~/.claude/skills/
```

복사 후 두 Skill 모두 다음 Claude Code 세션에서 자동으로 로드되고 사용자가 열 때마다 모든 프로젝트에서 사용 가능해집니다.

---

## 설치 후 스킬이 하는 일

### `harness-maker` (메인테이너용)

- 프로젝트 환경 감지 (언어, 패키지 관리자, 린터, 후크 시스템)
- `.harness/rules.yaml` 생성 및 유지 (선언적 규칙 목록)
- 규칙을 올바른 강제 메커니즘으로 연결 (린트 도구 / git 후크 / Claude Code 후크 / `.claude/rules/` 권고 파일)
- 기존 코드에서 규칙 위반 스캔 및 보고
- 규칙 추가, 수정 또는 제거 요청 처리

전체 설정 절차는 `skills/harness-maker/SKILL.md`를 참고하세요.

### `apply-harness` (기여자용)

- clone에 `.harness/rules.yaml`이 있는지 확인
- 메인테이너가 선택한 후크 러너 감지 (native `.githooks/`, Husky, Lefthook, pre-commit)
- 로컬에서 활성화 (`git config core.hooksPath …`, `husky install`, `lefthook install`, `pre-commit install`)
- `.harness/hooks/*.sh`에 실행 권한 부여
- 린터 의존성이 설치되지 않았으면 설치하도록 기여자에게 알림
- 멱등 — 이미 적용된 clone에서 재실행해도 안전

전체 활성화 절차는 `skills/apply-harness/SKILL.md`를 참고하세요.

---

## 향후 사용자 요청 대응

### `harness-maker`

| 사용자 요청 | 동작 |
|--------------|--------|
| "하네스에 규칙 추가해: ..." | `rules.yaml`에 추가 → 강제 메커니즘 구성 → 스캔 |
| "하네스 설정해줘" | `rules.yaml` 읽기 → 환경 검사 → 전체 구성 재생성 |
| "하네스 규칙 보여줘" | `rules.yaml` 읽기 및 예쁘게 출력 |
| "하네스 검사 실행해" | 모든 활성 규칙의 위반 사항 스캔 |
| "rule-003 삭제해" | `rules.yaml`에서 제거 + 관련 구성 정리 |
| "rule-001 severity를 error로 변경" | `rules.yaml` 업데이트 + 관련 구성에 전파 |

### `apply-harness`

| 사용자 요청 | 동작 |
|--------------|--------|
| "하네스 적용" / "apply harness" | 후크 러너 감지 → 로컬 활성화 → 린트 의존성 확인 |
| "하네스 온보딩" | 위와 동일; 이미 적용된 경우 멱등 처리 |

---

## 성능 예산

후크는 빨라야 합니다(pre-commit ≤ 2s, commit-msg ≤ 0.5s, Claude Code hook ≤ 1s). 그렇지 않으면 우회됩니다. 자세한 내용은 `skills/harness-maker/references/performance.md`를 참고하세요.
