---
name: plumblines-init
description: Bootstrap Plumblines project memory into a repo. Scaffolds the .agent_files tree, then reads the actual codebase to fill PROJECT_STATE.md with real content instead of blank templates. Use when a user wants to "set up Plumblines", "add agent memory", "initialise .agent_files", or onboard a project to the Plumblines continuity framework.
---

# Plumblines: initialise project memory

Goal: take a repo from "no agent memory" to "a populated, commit-anchored
`.agent_files/` that passes the completeness and staleness gates" — without
leaving the user a pile of blank templates to fill in.

## Step 1 — scaffold the tree

Detect which scaffolder to run. Both ship in `scripts/`:

- POSIX shell: `bash scripts/plumblines-init.sh [--team] [--hooks] [--ci]`
- PowerShell:  `pwsh scripts/plumblines-init.ps1 [-Team] [-Hooks] [-Ci]`

Choose the layout:

- **minimal** (default) for a single-codebase project.
- **--team / -Team** when the repo has clearly separable domains (e.g.
  `frontend/`, `auth/`, `payments/`) or multiple services.

If the scaffolder is not present in the target repo (the user only copied
`.agent_files/`), copy the canonical files yourself using the name mapping in
`docs/integration.md` — never leave template files under their lowercase names.

The scaffolder is idempotent: re-running it only adds what is missing. It also
auto-detects source globs and stamps the current commit into the state files.

## Step 2 — fill PROJECT_STATE.md from the real code

This is the step a plain script cannot do. Read the repo and replace the
placeholder prose in `<agent_dir>/PROJECT_STATE.md` with verified facts:

1. **Project summary** — from README, package manifest, and entrypoints.
2. **Architecture** — from the directory layout and how modules depend on
   each other. Describe what you can see, not what you assume.
3. **Main technologies** — read the dependency manifest (package.json,
   pyproject.toml, go.mod, Cargo.toml, etc.). Do not guess versions.
4. **Important directories** — the ones that actually exist.
5. **Stable decisions** — only ones you can point at with a file path. Label
   each `verified` (you read it in code) or `inferred` (strongly implied).
6. **Known constraints / risks** — from CI config, lockfiles, TODO/FIXME, and
   any ADRs under `docs/adr/`.

Trust discipline (this is enforced by `check-completeness.sh`):

- Mark something `verified` only if you read it in the source.
- Mark `inferred` when it is implied but not directly stated.
- Mark `assumed` / `needs-review` when you are guessing — and a record's
  `trust` must never exceed the lowest trust of its inputs.

## Step 3 — confirm source globs

Open `.plumblines` and check `src_globs` matches where this project keeps code.
The completeness gate only counts commits touching those globs, so a wrong glob
silently disables coverage. If the project keeps code somewhere unusual (e.g.
`scripts/ docs/`), fix `src_globs` and say so.

## Step 4 — verify the gates are green

Run, from the repo root:

```
bash scripts/check-staleness.sh
bash scripts/check-completeness.sh HEAD HEAD
```

Both should pass against the freshly scaffolded tree. If staleness flags the
state file, its `valid_as_of_commit` was not stamped — set it to the current
`git rev-parse HEAD`.

## Step 5 — report

Tell the user: the layout created, the detected `src_globs`, which files you
populated vs. left as stubs, and whether hooks/CI were installed. Point them at
`<agent_dir>/AGENT_RULES.md`, `CONTEXT_PRIORITY.md`, and `LOADING_POLICY.md` as
the files their coding agent should read before changing code.

Do not invent project facts to fill the template. An honest stub labelled
`needs-review` is better than confident fiction.
