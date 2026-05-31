# Plumblines

**A plain-Markdown project continuity framework for AI coding agents.**

AI coding agents lose context between sessions: they forget decisions, repeat
work, and act on stale assumptions. Plumblines gives them a lightweight memory
system inside a project — a `.agent_files/` directory of Markdown records for
project state, decisions, change history, risks, and assumptions, anchored to
commits so stale notes can be detected.

It is an **agent coordination layer**, not a replacement for your code, tests,
or docs. The source code is always the final truth.

**Suggested topics:** `ai-agents`, `coding-agents`, `context-engineering`, `claude-code`, `developer-tools`

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

1. Fill `PROJECT_STATE.md`, or run the **`plumblines-init` agent skill**, which
   reads your codebase and drafts it from real facts instead of blank prose.
2. Tell your agent to read `.agent_files/AGENT_RULES.md`, `CONTEXT_PRIORITY.md`,
   and `LOADING_POLICY.md` before changing code.
3. After each change, record one under `.agent_files/local/changes/` (the
   **`plumblines-change` skill** does this and verifies the gate).
4. Run the gates (below) in CI or a pre-push hook.

Full detail and the manual-copy name mapping: [`docs/integration.md`](docs/integration.md).
Visual record triage in Obsidian: [`docs/obsidian.md`](docs/obsidian.md).

---

## What it creates

```txt
.agent_files/
  AGENT_RULES.md          # how the agent should use the memory
  CONTEXT_PRIORITY.md     # which sources to trust when they conflict
  LOADING_POLICY.md       # what to read per task type
  PROJECT_STATE.md        # current state, architecture, decisions
  local/
    WORKING_STATE.md      # branch-local scratch (usually gitignored)
    changes/              # one record per change
  compacted/              # summaries of older records
  templates/
```

For large or multi-team codebases, add a `--team` layout with `shared/`
(cross-cutting state, decision log, known risks) and `domains/<domain>/STATE.md`
so agents load only the relevant domain. See the structures in
[`docs/integration.md`](docs/integration.md).

---

## Core principles

1. **Code is the final truth.** Memory helps agents understand faster; it never
   replaces reading the code.
2. **Memory is labelled.** Every record carries a trust level: `verified`,
   `inferred`, `assumed`, `needs-review`, or `stale`.
3. **Memory is anchored to commits.** Records include `valid_as_of_commit` so a
   record can be flagged when the files it depends on change later.
4. **Trust does not escalate.** A record's `trust` cannot exceed the lowest
   `trust` among its provenance inputs.
5. **Agents load selectively.** Read the relevant domain and recent records, not
   the whole tree.
6. **Every change leaves a trail.** Record what changed, why, files touched,
   validation, risks, follow-ups, and links to tickets/PRs/commits.
7. **Memory is compacted.** After ~10 records or a large task, fold older notes
   into a summary.

When sources conflict, trust order is: source code → tests → schemas/migrations
→ CI config → official docs → ADRs → tickets/PRs/commits → `.agent_files/shared`
→ `domains` → `local` → agent assumptions.

---

## The gates

```bash
bash scripts/check-staleness.sh                  # report (non-blocking)
bash scripts/check-completeness.sh origin/main HEAD   # enforce (blocking)
```

- **Staleness** flags records whose `depends_on` files changed after their
  `valid_as_of_commit`. Review and re-label or update them.
- **Completeness** enforces that every source-touching commit in a range has a
  change record, and that trust labels do not escalate.

Both share one deterministic frontmatter parser (`scripts/plumblines-lib.sh`)
and read `agent_dir` / `src_globs` from `.plumblines`. The gates check that a
record *exists* and that trust is honest — not that the prose is accurate; that
still needs human review. See [`docs/ci-wiring.md`](docs/ci-wiring.md) and
[`docs/record-schema.md`](docs/record-schema.md).

---

## Git strategy

Solo projects can gitignore the whole tree (`.agent_files/`). Teams commit the
reviewed shared context and keep only branch-local state out:

```gitignore
.agent_files/local/
```

---

## What's in this repository

```txt
docs/        framework.md, skill.md, record-schema.md, ci-wiring.md,
             integration.md, obsidian.md, v0.2-upgrade-notes.md
templates/   the record templates, plus obsidian/ dashboards
scripts/     plumblines-lib.sh, check-staleness.sh, check-completeness.sh,
             plumblines-init.sh, plumblines-init.ps1
skills/      plumblines-init, plumblines-change (agent skills)
```

---

## Status

Public framework draft, v0.2.1. Plain Markdown throughout, so it works with any
coding agent, editor, or repository.
