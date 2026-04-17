# 프로젝트 환경 감지

## 왜 중요한가

잘못된 환경 파악은 잘못된 메커니즘 선택으로 이어진다.
ESLint가 없는데 ESLint 규칙을 추가하거나, Husky v9인데 v4 문법으로
hook을 만들면 아무것도 동작하지 않는다.

이 레퍼런스는 2단계(메커니즘 검토)에서 프로젝트 환경을 정확히 파악하기 위한
체크리스트와 판단 기준을 제공한다.

---

## 감지 순서

빠르게 전체 그림을 잡는 순서로 진행한다.

### 1. 프로젝트 루트 스캔

```bash
# 한 번에 전체 상황 파악
ls -la | head -40
```

이것만으로도 많은 정보를 알 수 있다:
- `package.json` → Node.js/JS/TS 프로젝트
- `Cargo.toml` → Rust
- `go.mod` → Go
- `pyproject.toml` / `setup.py` / `requirements.txt` → Python
- `pom.xml` / `build.gradle` → Java/Kotlin
- `.sln` / `.csproj` → .NET
- `Makefile` / `CMakeLists.txt` → C/C++

### 2. 언어 및 런타임 버전

```bash
# Node.js
node --version 2>/dev/null
cat .nvmrc .node-version 2>/dev/null

# Python
python3 --version 2>/dev/null
cat .python-version 2>/dev/null

# 기타 — 필요한 것만
rustc --version 2>/dev/null
go version 2>/dev/null
```

### 3. 패키지 매니저

```bash
# lockfile로 판단 — 가장 정확
ls package-lock.json yarn.lock pnpm-lock.yaml bun.lockb 2>/dev/null
# package-lock.json → npm
# yarn.lock → yarn
# pnpm-lock.yaml → pnpm
# bun.lockb → bun

# Python
ls Pipfile.lock poetry.lock uv.lock 2>/dev/null
```

패키지 매니저를 정확히 아는 것은 중요하다.
패키지 설치 명령어가 다르고 (npm install vs pnpm add),
hook 도구의 설치 방법도 달라진다.

### 4. 린트/포맷 도구 감지

```bash
# JS/TS 생태계
ls .eslintrc* eslint.config.* 2>/dev/null          # ESLint
ls biome.json biome.jsonc 2>/dev/null               # Biome
ls .prettierrc* prettier.config.* 2>/dev/null       # Prettier
ls deno.json deno.jsonc 2>/dev/null                 # Deno (내장 린터/포맷터)
ls .oxlintrc.json oxlint.config.* 2>/dev/null       # oxlint
cat package.json 2>/dev/null | grep -E '"eslint|biome|prettier|oxlint"'

# Python
ls .ruff.toml ruff.toml 2>/dev/null                 # Ruff
ls .flake8 setup.cfg 2>/dev/null                    # Flake8
ls mypy.ini .mypy.ini 2>/dev/null                   # mypy
cat pyproject.toml 2>/dev/null | grep -E '\[tool\.(ruff|flake8|black|isort|mypy|pylint)\]'

# Rust
ls clippy.toml .clippy.toml rustfmt.toml 2>/dev/null

# Go
ls .golangci.yml .golangci.yaml 2>/dev/null
```

참고: oxlint는 ESLint보다 50-100배 빠른 Rust 기반 린터이다.
프로젝트에서 oxlint를 쓰고 있으면 ESLint 대신 oxlint에 규칙을 추가하는 것이 성능상 유리하다.
다만 oxlint는 커스텀 룰을 지원하지 않으므로, 내장 규칙에 없는 패턴은
ESLint나 커스텀 스크립트를 병행해야 한다.

#### ESLint 버전/설정 방식 구분

ESLint는 설정 방식이 버전에 따라 완전히 다르므로 정확히 파악해야 한다.

```bash
# 설정 파일 형태로 판단
if ls eslint.config.* 2>/dev/null; then
  echo "Flat config (ESLint 9+)"
elif ls .eslintrc* 2>/dev/null; then
  echo "Legacy config (ESLint 8 이하)"
fi

# 버전 직접 확인
npx eslint --version 2>/dev/null
```

- **Flat config** (`eslint.config.js/ts/mjs`): ESLint 9+. `export default [...]` 형태.
  plugins를 객체로 import해서 넣는다.
- **Legacy config** (`.eslintrc.json/.js/.yaml`): ESLint 8 이하. `extends`, `plugins`
  문자열 배열. `overrides`로 파일별 설정.

이 둘의 문법은 호환되지 않으므로 반드시 구분한다.

### 5. Hook 시스템 감지

```bash
# Husky
if [ -d .husky ]; then
  echo "Husky detected"
  ls .husky/
  # v9+ 확인: .husky/_/husky.sh 없으면 v9
  [ -f .husky/_/husky.sh ] && echo "Husky v4-v8" || echo "Husky v9+"
fi

# Lefthook
ls .lefthook.yml .lefthook-local.yml lefthook.yml 2>/dev/null

# pre-commit (Python 생태계)
ls .pre-commit-config.yaml 2>/dev/null

# Native git hooks
ls .git/hooks/ 2>/dev/null | grep -v '.sample'
git config core.hooksPath 2>/dev/null

# lint-staged
cat package.json 2>/dev/null | grep -A5 '"lint-staged"'
ls .lintstagedrc* lint-staged.config.* 2>/dev/null
```

### 6. 모노레포 감지

```bash
# 워크스페이스 설정 확인
cat package.json 2>/dev/null | grep -A5 '"workspaces"'
ls pnpm-workspace.yaml 2>/dev/null
ls lerna.json nx.json turbo.json 2>/dev/null

# 패키지 구조 확인
ls packages/ apps/ libs/ modules/ 2>/dev/null
```

모노레포일 경우 규칙의 scope가 중요해진다.
전체 레포 규칙인지, 특정 패키지 규칙인지 유저에게 확인한다.

### 7. Claude 환경 감지

```bash
# CLAUDE.md 존재 및 내용 확인
cat CLAUDE.md 2>/dev/null | head -30

# .claude/rules/ 개별 규칙 파일
ls .claude/rules/*.md 2>/dev/null

# Claude Code 설정 및 기존 hooks
cat .claude/settings.json 2>/dev/null

# 하위 디렉토리에 CLAUDE.md가 있는지
find . -name "CLAUDE.md" -maxdepth 3 2>/dev/null

# Claude Code 사용 가능 여부 (Claude Code 환경에서만 의미 있음)
which claude 2>/dev/null && echo "Claude Code CLI 설치됨"
```

### 8. 기존 하네스 상태 확인

```bash
# 하네스가 이미 설정되어 있는지
cat .harness/rules.yaml 2>/dev/null

# 하네스 hook 스크립트
ls .harness/hooks/ 2>/dev/null
```

기존 하네스가 있으면 rules.yaml에서 현재 규칙 목록과 사용 중인 메커니즘을 파악한다.
새 규칙은 기존 패턴을 따르는 것이 일관성 있다.

---

## 감지 결과 정리 형식

환경 감지 후 내부적으로 다음 형태로 정리하면 이후 단계에서 참조하기 좋다.
유저에게는 핵심만 요약해서 전달한다.

```
프로젝트 환경:
- 언어: TypeScript
- 런타임: Node 20
- 패키지 매니저: pnpm
- 린터: Biome (biome.json, v1.9)
- 포맷터: Biome (통합)
- Hook: Husky v9 + lint-staged
- 모노레포: pnpm workspace (packages/*)
- Claude: CLAUDE.md 있음, .claude/rules/ 3개 규칙, hooks 2개 설정
- 하네스: .harness/rules.yaml 있음 (5개 규칙 활성)
```

---

## 감지 실패 시

도구가 설치되어 있지만 설정 파일이 없거나, 설정 파일이 비어있는 경우가 있다.
이럴 때는:

- 도구가 있지만 설정이 없으면: 기본 설정으로 시작하는 안을 제안
- 도구 자체가 없으면: 규칙에 가장 적합한 도구를 제안하되, 유저의 동의를 먼저 구한다.
  새 도구 도입은 유저가 명시적으로 동의한 경우에만 진행한다.
- 여러 도구가 겹치면 (ESLint + Biome 등): 유저에게 어느 쪽에 규칙을 넣을지 확인한다.
