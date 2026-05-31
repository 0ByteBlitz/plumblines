# Plumblines

**A plain-Markdown project continuity framework for AI coding agents.**

Plumblines helps AI coding agents preserve project context across sessions, record changes, track assumptions, detect stale memory, and avoid repeatedly rediscovering the same codebase decisions.

It creates a lightweight memory system inside a project using a `.agent_files/` directory.

**Repo description:** A plain-Markdown project continuity framework for AI coding agents.

**Suggested topics:** `ai-agents`, `coding-agents`, `context-engineering`, `claude-code`, `developer-tools`

---

## Why this exists

AI coding agents often struggle with continuity. They may forget previous decisions, repeat work, misread architecture, or confidently act on stale assumptions.

Plumblines gives agents a clear place to read and write project context:

- current project state
- architecture and design notes
- working branch state
- change history
- validation logs
- risks and follow-ups
- verified decisions vs assumptions
- commit-anchored validity metadata
- compaction summaries after many iterations

---

## Core idea

Plumblines is not a replacement for your codebase, tests, pull requests, or official documentation.

It is an **agent coordination layer**.

When sources conflict, trust them in this order:

1. Source code
2. Tests
3. API schemas, migrations, generated types
4. CI/CD configuration
5. Official documentation
6. Architecture Decision Records
7. Tickets, PRs, and commit history
8. `.agent_files/shared`
9. `.agent_files/domains`
10. `.agent_files/local`
11. Agent assumptions

The source code remains the final truth.

---

## What changed in v0.2

Plumblines v0.2 responds to the biggest weakness of passive Markdown memory: agents can skip it, and stale notes can silently become wrong.

New mechanics:

- **Loading policy**: tells agents what to read and what to skip per task type.
- **Commit anchoring**: state files and change records include `valid_as_of_commit`.
- **Staleness checker**: optional Git-based script flags records whose dependent files changed after their validity commit.
- **Provenance tracking**: records which sources and assumptions informed a decision.
- **Completion checks**: code changes are not complete until the change record, validation, risks, and follow-ups are recorded.

See [`docs/v0.2-upgrade-notes.md`](docs/v0.2-upgrade-notes.md).

---

## What changed in v0.2.1

Plumblines v0.2.1 adds an enforcement gate and deterministic record parser.

New mechanics:

- **Enforcement gate**: `scripts/check-completeness.sh` checks coverage and provenance. Source-touching commits in a configured range must have a change record, and a record's trust cannot exceed the lowest-trust provenance input.
- **CI/hook wiring**: the completeness gate can run in CI or a pre-push hook. See [`docs/ci-wiring.md`](docs/ci-wiring.md).
- **YAML frontmatter record schema**: records now put machine-readable metadata in YAML frontmatter. See [`docs/record-schema.md`](docs/record-schema.md).
- **Shared parser**: both check scripts parse records through `scripts/plumblines-lib.sh`, so staleness and completeness checks do not drift apart.

---

## Minimal project structure

```txt
.agent_files/
  AGENT_RULES.md
  CONTEXT_PRIORITY.md
  LOADING_POLICY.md
  PROJECT_STATE.md

  docs/
    system-design.md
    frontend-design.md
    design-language.md

  local/
    WORKING_STATE.md
    changes/

  compacted/

  templates/
```

---

## Team or large-codebase structure

```txt
.agent_files/
  README.md
  AGENT_RULES.md
  CONTEXT_PRIORITY.md
  LOADING_POLICY.md

  shared/
    PROJECT_STATE.md
    ARCHITECTURE_SUMMARY.md
    DESIGN_SYSTEM_SUMMARY.md
    API_CONTRACT_SUMMARY.md
    SECURITY_RULES.md
    DECISION_LOG.md
    KNOWN_RISKS.md

  domains/
    frontend/
      STATE.md
      DESIGN_NOTES.md
      DECISION_LOG.md
      changes/

    auth/
      STATE.md
      DECISION_LOG.md
      changes/

    payments/
      STATE.md
      DECISION_LOG.md
      changes/

  local/
    WORKING_STATE.md
    scratch.md
    changes/

  compacted/

  templates/
```

---

## Recommended Git strategy

For solo projects, you can keep everything local:

```gitignore
.agent_files/
```

For team projects, use a hybrid approach:

```gitignore
.agent_files/local/
```

Commit reviewed shared context:

```txt
.agent_files/README.md
.agent_files/AGENT_RULES.md
.agent_files/CONTEXT_PRIORITY.md
.agent_files/LOADING_POLICY.md
.agent_files/shared/
.agent_files/domains/
.agent_files/templates/
```

Keep temporary agent state local:

```txt
.agent_files/local/
```

---

## Core principles

### 1. Code is the final truth

Plumblines helps agents understand the project faster, but it must never replace reading the actual code.

### 2. Memory must be labelled

Important observations should be labelled as:

- `verified`
- `inferred`
- `assumed`
- `needs-review`
- `stale`

### 3. Memory should be anchored to commits

State files and change records should include:

```txt
valid_as_of_commit: COMMIT_SHA
```

This allows stale records to be found when related files change later.

### 4. Provenance trust must not escalate

A record's `trust` cannot exceed the lowest `trust` among its provenance inputs. See [`docs/record-schema.md`](docs/record-schema.md).

### 5. Agents should load selectively

Agents should read the relevant domain and latest related records, not the whole `.agent_files/` tree.

### 6. Every change should leave a trail

After modifying a codebase, an agent should record:

- what changed
- why it changed
- files touched
- validation performed
- risks
- follow-ups
- links to tickets, PRs, branches, or commits

### 7. Memory must be compacted

After about 10 change records, or after a large task, compact older notes into a summary.

---

## What is included in this repository

```txt
docs/
  framework.md
  skill.md
  v0.2-upgrade-notes.md
  record-schema.md
  ci-wiring.md
  integration.md
  obsidian.md

templates/
  context-priority.md
  loading-policy.md
  project-state.md
  working-state.md
  domain-state.md
  change.md
  validation.md
  decisions.md
  provenance.md
  risks.md
  followups.md
  compaction.md
  obsidian/
    plumblines.base
    Dashboard.md

scripts/
  plumblines-lib.sh
  check-staleness.sh
  check-completeness.sh
  plumblines-init.sh
  plumblines-init.ps1

skills/
  plumblines-init/SKILL.md
  plumblines-change/SKILL.md
```

---

## Quick start

One command scaffolds the whole `.agent_files/` tree, copies templates under
their canonical names, detects your source directories, writes a `.plumblines`
config, patches `.gitignore`, and stamps the current commit into the state
files:

```bash
bash scripts/plumblines-init.sh            # minimal layout
bash scripts/plumblines-init.sh --team --hooks --ci
```

```powershell
pwsh scripts/plumblines-init.ps1           # Windows
pwsh scripts/plumblines-init.ps1 -Team -Hooks -Ci
```

It is idempotent — re-running only adds what is missing. Then:

1. Fill `PROJECT_STATE.md` — or run the **`plumblines-init` agent skill**, which
   reads your codebase and drafts it from real facts instead of blank prose.
2. Tell your coding agent to read `.agent_files/AGENT_RULES.md`,
   `CONTEXT_PRIORITY.md`, and `LOADING_POLICY.md` before modifying code.
3. After each change, create a record under `.agent_files/local/changes/` (the
   **`plumblines-change` skill** does this and verifies the gate).
4. Run `scripts/check-staleness.sh` and `scripts/check-completeness.sh`, in CI
   or a pre-push hook. See [`docs/ci-wiring.md`](docs/ci-wiring.md).
5. Compact older records when the history becomes noisy.

Full detail and the manual-copy name mapping: [`docs/integration.md`](docs/integration.md).

Want a visual lens on your records? Plumblines frontmatter maps directly onto
Obsidian Properties — run the scaffolder with `--obsidian` for ready-made Bases
and Dataview dashboards, and see [`docs/obsidian.md`](docs/obsidian.md).

---

## Suggested agent instruction

```txt
Before changing this codebase, read `.agent_files/AGENT_RULES.md`, `.agent_files/CONTEXT_PRIORITY.md`, `.agent_files/LOADING_POLICY.md`, `.agent_files/PROJECT_STATE.md`, and the relevant domain state. Load only task-relevant memory. After making changes, create or update a change record under `.agent_files/local/changes/` using the Plumblines templates. The task is not complete until validation, risks, follow-ups, touched files, and valid_as_of_commit are recorded, or until you state that no files were changed.
```

---

## Optional staleness check

```bash
bash scripts/check-staleness.sh
```

The script scans `.agent_files` for Markdown records with `valid_as_of_commit` and flags records whose listed files changed after that commit.

---

## Completeness gate

```bash
bash scripts/check-completeness.sh origin/main HEAD
```

The gate enforces that a record exists and that trust labels do not escalate. It does not verify that the prose is accurate; that still needs review.

---

## Status

Public framework draft, upgraded to v0.2.1. The structure remains plain Markdown so it works with any coding agent, editor, or repository.
