# Skill-based rule enforcement

## When a Skill is the right mechanism

Use a Skill when the rule is a **task-scoped procedure** — a *how-to* that applies
only when a specific kind of work is being done. Signals that a rule belongs in a
Skill rather than a hook or a lint rule:

- The rule describes a *process* ("when designing X, do Y"), not a content
  constraint ("never write X").
- The rule only applies during that kind of work — not on every file touch.
- The rule is about *doing something* (creating an artifact, following a
  template), not about *avoiding a pattern*.
- The natural violation is **absence** (forgot to create the artifact at all) —
  no post-hoc scanner can catch this, but a Skill invoked at task start can.
- Non-determinism is acceptable: the agent may need to exercise judgment
  inside the procedure.

If those signals don't apply, use a lint rule, a Claude Code hook, or a git
hook instead — see `SKILL.md` §3 for the classification flow.

## Why Skills over advisory files for procedures

`.claude/rules/*.md` files are advisory: Claude may load them when editing matching
files, but for a *procedure rule*, the relevant moment is **the user asking for a
kind of work**, not a file edit. A Skill's `description` field makes Claude pull
the procedure into context at that exact moment.

A Skill *prevents* the violation by front-loading the procedure; a hook *detects*
a violation after it has occurred. For rules where absence is the violation,
only the Skill approach works.

## File layout

```
.claude/skills/
  <skill-name>/
    SKILL.md          ← entry point (required)
    references/       ← optional, loaded on demand
    templates/        ← optional, copied into target files
```

Project-scoped (`.claude/skills/`) travels with the repo. Personal-scoped
(`~/.claude/skills/`) is per-user. Project-scoped is correct for harness rules.

## SKILL.md template

```markdown
---
name: <skill-name>
description: Use this skill when <task description>. Trigger phrases include "<phrase 1>", "<phrase 2>", "<phrase in user's language>".
---

# [Harness: rule-XXX] <skill-name>

When the user asks for <this kind of work>, follow this procedure.

## 1. <First concrete step>

<Exactly what to do, including file paths, naming conventions, templates.>

## 2. <Next step>

...

## Before returning to the user

- Confirm <the produced artifact matches the rule>.
- <Any reporting the procedure requires.>
```

Keep the body short enough to be loaded without burning context — anything
that's conditional or rarely needed goes under `references/` inside the Skill.

## Writing the `description` field

The `description` is the only thing Claude sees when deciding whether to load
the Skill. Include:

- The task verb and object, expressed in each language the team uses when
  requesting this work (for example, both the English phrasing and any
  localized phrasing common on the team).
- Common synonyms and adjacent operations (`"schema change"`, `"migration"`,
  `"alter column"`).
- Concrete artifacts users mention when asking for the work
  (`"CREATE TABLE"`, `"new entity"`, `"DDL"`).

A narrow, specific description loads only for the right tasks. A vague
description loads too often, wastes context, and competes with other Skills.

`task_triggers` entries in `rules.yaml` map directly into this description.

## Tag the Skill to its rule

Every harness-generated artifact must carry its originating rule id (rule-002,
`harness-artifact-tag-required`). For a Skill:

- Put `[Harness: rule-XXX]` in the H1 heading or body prose of `SKILL.md`.
- If the Skill ships helper scripts in its own tree, add `# harness: rule-XXX`
  as a header comment to each script.

This lets harness-maker later update, relocate, or delete the Skill when the
owning rule changes.

## Pairing a Skill with other mechanisms

A Skill is the *primary* mechanism for procedure rules, but it can be
reinforced:

- **`.claude/rules/*.md`** — same rule as advisory text, loaded whenever files
  matching `globs` are edited. Catches the case where Claude touches related
  files without the task phrasing triggering the Skill.
- **Claude Code `PostToolUse` hook** on the target path pattern — deterministic
  check that the produced artifact matches the required shape (for example, a
  filename regex). Confirms the Skill was followed even when it was invoked.
- **Git `pre-commit` hook** — only as a last-resort backstop if the artifact
  must not reach the repo in the wrong shape. Usually unnecessary for
  procedure rules, since the Skill prevents the issue upstream. Do *not* rely
  on this as the primary mechanism for a procedure rule.

## Updating an existing Skill vs creating a new one

Before creating a new Skill, check whether an existing one already covers
adjacent work:

```bash
ls .claude/skills/ ~/.claude/skills/ 2>/dev/null
```

If an existing Skill's scope overlaps, extend its `description` and add a new
section to its body — do not create a sibling Skill that competes for the same
trigger phrases. Competing descriptions make Claude's Skill-selection
unreliable.

## Minimal example (file-placement procedure)

Rule: *"When the user asks for table design, save SQL as
`scheme/YYYYMMDD_TableName.sql`."*

`rules.yaml`:

```yaml
- id: rule-042
  name: scheme-sql-file
  description: "Table design work produces scheme/YYYYMMDD_TableName.sql"
  kind: task-procedure
  severity: error
  scope:
    task_triggers:
      - "design a table"
      - "schema change"
      - "add a migration"
      - "alter table"
    artifact_glob: "scheme/*.sql"
  pattern: '^scheme/[0-9]{8}_[A-Z][A-Za-z0-9]*\.sql$'
```

`.claude/skills/design-table/SKILL.md`:

```markdown
---
name: design-table
description: Use this skill when the user asks to design a table, change a schema, add a migration, or alter DB structure. Trigger phrases include "design a table", "new table", "schema change", "add a migration", "alter table", "CREATE TABLE", and any localized equivalents the team uses.
---

# [Harness: rule-042] design-table

When the user asks for table-design work, follow this procedure before writing SQL.

## 1. Decide the filename

Files go under `scheme/` at the repo root with the name `YYYYMMDD_TableName.sql`:
- Date: today, 8 digits (for example `20260421`).
- Table name: PascalCase (for example `StoreFAQ`).

Confirm with the user if the table name is unclear — do not guess.

## 2. Draft the SQL

Use the project's existing migrations as a style reference. Include primary
keys, explicit column types, and `NOT NULL` defaults where applicable.

## 3. Before returning to the user

- Confirm the path matches `scheme/YYYYMMDD_TableName.sql`.
- Link the created file in the reply.
```

Optional reinforcement — a `PostToolUse` hook that fails fast if Claude writes
a file under `scheme/` with the wrong filename shape:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "if": "Write(scheme/*)",
            "command": ".harness/hooks/check-scheme-filename.sh"
          }
        ]
      }
    ]
  }
}
```

The hook is a backstop, not the primary enforcement. The Skill's job is to
make sure the right filename is chosen in the first place.
