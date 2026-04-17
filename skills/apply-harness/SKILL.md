---
name: apply-harness
description: Activate a shared harness config in the current local clone — wire up git hooks, set core.hooksPath, make check scripts executable, and verify linter deps are installed. Use when a contributor has cloned a repo that already contains .harness/rules.yaml and needs to opt their local checkout in. Trigger phrases include "apply harness", "하네스 적용", "팀 harness 세팅", "activate shared harness", "enable harness locally", "onboard to harness".
---

# Apply Harness

`harness-maker` writes harness config into a repo — `.harness/rules.yaml`, `.harness/hooks/*.sh`, the hook-runner config (`.githooks/`, `.husky/`, `lefthook.yml`, or `.pre-commit-config.yaml`), and `.claude/rules/*.md`. Most of that is committed and travels with the repo.

**But the piece that actually activates git hooks is per-clone local state.** `git config core.hooksPath`, `husky install`, `lefthook install`, and `pre-commit install` all write to the contributor's local `.git/config` or `.git/hooks/`, not to anything git tracks. Contributors who clone the repo must re-run that activation — this Skill does that.

### Preconditions

- The repo has `.harness/rules.yaml` (if not, run `harness-maker` first — this Skill assumes the harness already exists).
- The user is inside the repo (`cd` into it).

### Activation procedure

#### 1. Verify harness exists

```bash
test -f .harness/rules.yaml || { echo "No .harness/rules.yaml — nothing to apply. Run harness-maker first."; exit 1; }
```

Read `.harness/rules.yaml` and show the contributor the rule list (id, name, severity) so they know what they're opting into before activation.

#### 2. Detect the hook runner

Inspect which hook system the maintainer chose:

```bash
ls -d .githooks .husky 2>/dev/null
ls lefthook.yml .lefthook.yml lefthook.yaml .lefthook.yaml .pre-commit-config.yaml 2>/dev/null
# Fallback: package.json may declare husky/lefthook as devDependencies
```

| Artifact found | Hook system |
|---|---|
| `.githooks/` directory | Native (set `core.hooksPath`) |
| `.husky/` directory or `husky` in devDeps | Husky |
| `lefthook.yml` / `.lefthook.yml` / `lefthook.yaml` | Lefthook |
| `.pre-commit-config.yaml` | pre-commit (Python framework) |

If none are detected but `.harness/hooks/*.sh` exists, ask the user — the maintainer may have shipped scripts without choosing a runner.

#### 3. Activate the detected runner

Run only the branch matching what was detected in step 2.

**Native `.githooks/`:**
```bash
git config core.hooksPath .githooks
chmod +x .githooks/*
chmod +x .harness/hooks/*.sh 2>/dev/null || true
```

**Husky:**
```bash
# husky v9+: `prepare` script in package.json is the canonical activator.
# Prefer running the project's install command which triggers it.
pnpm install || yarn install || npm install
# If no prepare script exists, fall back to:
# bunx husky
chmod +x .harness/hooks/*.sh 2>/dev/null || true
```

**Lefthook:**
```bash
bunx lefthook install
chmod +x .harness/hooks/*.sh 2>/dev/null || true
```

**pre-commit (Python):**
```bash
pre-commit install
```

#### 4. Verify linter dependencies

Lint rules in `eslint.config.*`, `biome.json`, `.ruff.toml`, etc. are committed and travel with the repo — but the tool binaries are not. Check that the declared package manager has installed them:

```bash
# Node projects
test -d node_modules || echo "⚠ Run pnpm install / yarn install / npm install"
# Python projects
test -d .venv || python -c "import ruff" 2>/dev/null || echo "⚠ Install Python linter deps"
# Rust
test -d target || echo "⚠ Run cargo build (clippy ships with rustup)"
```

**Do not run the install automatically** — dep installs are too side-effectful for a bring-up script. Print a reminder and let the contributor run it themselves.

#### 5. Idempotency

Before activating, check whether the harness is already applied and short-circuit with a "already applied" message:

| Runner | Already-applied signal |
|---|---|
| Native | `git config core.hooksPath` returns `.githooks` |
| Husky | `git config core.hooksPath` returns `.husky/_` |
| Lefthook | `.git/hooks/pre-commit` contains `lefthook` |
| pre-commit | `.git/hooks/pre-commit` contains `pre-commit` |

Re-running this Skill on an already-applied clone should be safe and silent.

#### 6. Report

Tell the contributor:

- Detected hook runner
- What was activated (`core.hooksPath = .githooks`, or equivalent)
- Number of rules now active (from `rules.yaml`)
- Any remaining manual step (e.g., "run `pnpm install` — linter deps not installed")
- A one-liner for how to verify: `git commit --allow-empty -m "test" --dry-run` style, or run one check script directly

### When not to use this Skill

| Situation | Use instead |
|---|---|
| No `.harness/rules.yaml` in the repo | `harness-maker` (create the harness first) |
| Want to add a new rule | `harness-maker` |
| Want to remove or modify a rule | `harness-maker` |
| Want to run harness checks on current state | Either Skill can invoke `.harness/hooks/check-*.sh` directly |

This Skill is **read-only with respect to `.harness/` and `rules.yaml`** — it only wires up local git config and reports status.
