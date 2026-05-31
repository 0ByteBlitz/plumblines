# Plumblines

**A plain-Markdown continuity framework for AI coding agents.**

AI agents forget decisions between sessions and act on stale assumptions.
Plumblines gives them a `.agent_files/` memory layer — project state, decisions,
change history, and risks as Markdown records anchored to commits, with gates
that flag stale or undocumented changes.

It's a coordination layer, not a source of truth: the code always wins.

## Quick start

```bash
npx plumblines init                        # scaffold .agent_files/
npx plumblines init --team --hooks --ci --obsidian
```

Pure Node, no dependencies, nothing to clone. Then:

1. Fill `PROJECT_STATE.md` — or run the **`plumblines-init`** skill to draft it
   from your codebase.
2. Point your agent at `.agent_files/AGENT_RULES.md` before it changes code.
3. Record each change under `.agent_files/local/changes/` (the
   **`plumblines-change`** skill does this).

From a clone instead: `bash scripts/plumblines-init.sh` (or
`pwsh scripts/plumblines-init.ps1`). Full setup, layouts, and the manual-copy
mapping: [docs/integration.md](docs/integration.md).

## Installing the agent skills

Copy them where your agent looks for skills. For Claude Code:

```bash
cp -r skills/plumblines-init skills/plumblines-change .claude/skills/   # or ~/.claude/skills/
```

PowerShell: `Copy-Item -Recurse skills\plumblines-init, skills\plumblines-change .claude\skills\`.
Other agents: point them at the `SKILL.md` files directly — they're plain Markdown.

## What it creates

```txt
.agent_files/
  AGENT_RULES.md        # how the agent uses the memory
  CONTEXT_PRIORITY.md   # which sources win when they conflict
  LOADING_POLICY.md     # what to read per task
  PROJECT_STATE.md      # state, architecture, decisions
  local/changes/        # one record per change
  compacted/            # summaries of older records
```

`--team` adds `shared/` and `domains/<domain>/` for large codebases.

## How it works

- Each record carries a **trust** label (`verified`, `inferred`, `assumed`,
  `needs-review`, `stale`) and a `valid_as_of_commit`, so memory can be flagged
  when its dependencies change.
- Two gates keep it honest — **staleness** reports records whose deps moved;
  **completeness** blocks source commits with no change record (and trust that
  escalates above its inputs):

```bash
npx plumblines check          # completeness (blocking) + staleness (report)
```

## Learn more

| Doc | What |
|---|---|
| [integration.md](docs/integration.md) | install paths, layouts, name mapping |
| [framework.md](docs/framework.md) | the full model and principles |
| [record-schema.md](docs/record-schema.md) | the frontmatter contract |
| [ci-wiring.md](docs/ci-wiring.md) | hooks and CI |
| [obsidian.md](docs/obsidian.md) | record dashboards in Obsidian |

## Status

v0.3.1 — public draft. Plain Markdown throughout; works with any coding agent,
editor, or repository.
