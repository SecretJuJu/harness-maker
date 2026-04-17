# ESLint 기반 규칙 강제

## 언제 사용하나

코드 스타일, 금지 패턴, import 제한, 네이밍 컨벤션 등
**정적 분석으로 검출 가능한 코드 규칙**에 사용한다.

## 사전 확인

규칙을 추가하기 전에 프로젝트의 ESLint 상태를 파악한다:

```bash
# ESLint 설정 파일 찾기
ls -la .eslintrc* eslint.config.* 2>/dev/null
cat package.json | grep -A5 '"eslintConfig"' 2>/dev/null

# flat config vs legacy 확인
# eslint.config.js/ts/mjs가 있으면 → flat config (ESLint 9+)
# .eslintrc.*가 있으면 → legacy config

# ESLint 설치 여부
npx eslint --version 2>/dev/null
```

## 기존 ESLint 규칙으로 해결 가능한 경우

많은 규칙이 ESLint 내장 또는 유명 플러그인으로 커버된다.
커스텀 룰을 작성하기 전에 항상 기존 규칙을 먼저 확인한다.

### 자주 쓰이는 매핑

| 유저 요청 | ESLint 규칙 |
|-----------|------------|
| arrow function 대신 function 키워드 | `func-style: ["warn", "declaration"]` |
| var 금지 | `no-var: "error"` |
| console.log 금지 | `no-console: "warn"` |
| 특정 모듈 import 금지 | `no-restricted-imports` |
| 특정 전역 변수 금지 | `no-restricted-globals` |
| 특정 문법 금지 | `no-restricted-syntax` (AST selector 사용) |
| 네이밍 컨벤션 | `@typescript-eslint/naming-convention` |
| import 순서 | `import/order` (eslint-plugin-import) |
| 미사용 변수 | `no-unused-vars` 또는 `@typescript-eslint/no-unused-vars` |

### `no-restricted-syntax` 활용

AST selector를 사용하면 거의 모든 문법 패턴을 잡을 수 있다.
커스텀 룰을 만들기 전에 이 규칙으로 해결 가능한지 먼저 시도한다.

**예시: arrow function을 변수에 할당하는 패턴 금지**
```json
{
  "no-restricted-syntax": [
    "warn",
    {
      "selector": "VariableDeclarator > ArrowFunctionExpression",
      "message": "이 프로젝트는 function 키워드를 선호합니다. const fn = () => {} 대신 function fn() {}을 사용하세요."
    }
  ]
}
```

**예시: default export 금지**
```json
{
  "no-restricted-syntax": [
    "error",
    {
      "selector": "ExportDefaultDeclaration",
      "message": "named export만 사용하세요."
    }
  ]
}
```

AST selector 문법은 https://eslint.org/docs/latest/extend/selectors 참조.
AST Explorer(https://astexplorer.net)에서 패턴의 AST 구조를 확인할 수 있다.

## 설정 파일 수정

### Flat config (eslint.config.js) — ESLint 9+

```javascript
// 기존 파일에 규칙 추가
export default [
  // ... 기존 설정 유지
  {
    files: ["src/**/*.ts"],  // scope에 맞게 glob 조정
    rules: {
      "func-style": ["warn", "declaration"],
      // 새 규칙 추가
    }
  }
];
```

**Flat config 주요 함정:**
- `plugins`는 문자열 배열이 아닌 **객체**로 넘긴다: `plugins: { "@typescript-eslint": tseslint }`
- `extends`는 없다. 대신 spread로 shared config를 펼친다: `...tseslint.configs.recommended`
- `.eslintignore`는 무시됨. `ignores` 키를 설정 배열의 최상위 객체에 넣는다
- 기존 `overrides`는 `files` 키가 있는 별도 설정 객체로 대체

**TypeScript 프로젝트 참고:**
`@typescript-eslint` 규칙을 쓰려면 파서 설정이 필요하다.
기존 설정에 이미 있는지 확인하고, 없으면:

```javascript
import tseslint from "typescript-eslint";

export default tseslint.config(
  ...tseslint.configs.recommended,
  {
    files: ["src/**/*.ts"],
    rules: {
      // 하네스 규칙 추가
    }
  }
);
```

### Legacy config (.eslintrc.json)

```json
{
  "rules": {
    "func-style": ["warn", "declaration"]
  },
  "overrides": [
    {
      "files": ["src/**/*.ts"],
      "rules": {
        "추가-규칙": "warn"
      }
    }
  ]
}
```

## 커스텀 ESLint 룰 작성

기존 규칙으로 안 되는 복잡한 패턴이면 로컬 커스텀 룰을 만든다.

### 디렉토리 구조

```
.harness/
  eslint-rules/
    rule-name.js
```

### 룰 템플릿

flat config(ESM) 환경이면 `export default`를, legacy config(CJS)면 `module.exports`를 쓴다.

**ESM (flat config 프로젝트):**
```javascript
// .harness/eslint-rules/rule-name.js
export default {
  meta: {
    type: "suggestion",
    docs: { description: "규칙 설명" },
    messages: { violation: "위반 메시지: {{ detail }}" },
    fixable: "code",
    schema: []
  },
  create(context) {
    return {
      ArrowFunctionExpression(node) {
        context.report({
          node,
          messageId: "violation",
          data: { detail: "추가 설명" },
        });
      }
    };
  }
};
```

**CJS (legacy config 프로젝트):**
```javascript
// .harness/eslint-rules/rule-name.js
module.exports = {
  meta: {
    type: "suggestion",
    docs: { description: "규칙 설명" },
    messages: { violation: "위반 메시지: {{ detail }}" },
    fixable: "code",
    schema: []
  },
  create(context) {
    return {
      ArrowFunctionExpression(node) {
        context.report({
          node,
          messageId: "violation",
          data: { detail: "추가 설명" },
        });
      }
    };
  }
};
```

프로젝트의 `package.json`에 `"type": "module"`이 있으면 ESM, 없으면 CJS가 기본이다.

### 커스텀 룰 등록

**Flat config:**
```javascript
import ruleName from "./.harness/eslint-rules/rule-name.js";

export default [
  {
    plugins: {
      harness: { rules: { "rule-name": ruleName } }
    },
    rules: {
      "harness/rule-name": "warn"
    }
  }
];
```

**Legacy config + eslint-plugin-rulesdir:**
```bash
npm install --save-dev eslint-plugin-rulesdir
```
```json
{
  "plugins": ["rulesdir"],
  "settings": {
    "rulesdir/rules": [".harness/eslint-rules"]
  },
  "rules": {
    "rulesdir/rule-name": "warn"
  }
}
```

## 위반 스캔 실행

```bash
# 특정 규칙만 체크
npx eslint --rule '{"func-style": ["warn", "declaration"]}' "src/**/*.ts"

# 전체 린트
npx eslint .

# 자동 수정 가능한 것들 수정
npx eslint --fix .
```
