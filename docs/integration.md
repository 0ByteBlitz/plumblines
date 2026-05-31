# Integrating Plumblines into a project

Three ways in, from least to most automated. They are complementary — the
scaffolder does the mechanical setup; the agent skill fills it with real
content.

## 1. One command (recommended)

From the root of the project you want to add memory to, with the Plumblines
`scripts/` and `templates/` available:

```bash
# POSIX shell
bash scripts/plumblines-init.sh            # minimal layout
bash scripts/plumblines-init.sh --team --hooks --ci
```

```powershell
# Windows / PowerShell
pwsh scripts/plumblines-init.ps1            # minimal layout
pwsh scripts/plumblines-init.ps1 -Team -Hooks -Ci
```

The scaffolder:

- creates the `.agent_files/` tree (minimal or `--team`/`-Team`),
- copies templates under their **canonical names** (see mapping below),
- auto-detects source directories and writes a `.plumblines` config,
- appends `.agent_files/local/` to `.gitignore`,
- stamps the current commit into the state files so they pass staleness,
- optionally installs the pre-push hook (`--hooks`) and CI workflow (`--ci`).

It is **idempotent**: existing files are never overwritten, only reported as
skipped. Safe to re-run after a Plumblines upgrade.

## 2. Agent skill (fills the blank page)

A scaffolder can create the files but cannot know what your project *is*. The
`plumblines-init` skill runs the scaffolder, then reads your actual codebase to
populate `PROJECT_STATE.md` with verified facts (architecture, technologies,
directories, decisions) instead of placeholder prose. After making changes, the
`plumblines-change` skill authors a compliant change record and checks the gate.

Both live under `skills/`. Point your coding agent at them, or invoke them
directly if your agent supports skills.

## 3. Manual copy

If you only have the templates, copy them yourself using this mapping. The
lowercase template names are **not** the in-project names:

| Template                     | Lives at                               |
|------------------------------|----------------------------------------|
| `templates/AGENT_RULES.md`      | `.agent_files/AGENT_RULES.md`        |
| `templates/context-priority.md` | `.agent_files/CONTEXT_PRIORITY.md`   |
| `templates/loading-policy.md`   | `.agent_files/LOADING_POLICY.md`     |
| `templates/project-state.md`    | `.agent_files/PROJECT_STATE.md`      |
| `templates/working-state.md`    | `.agent_files/local/WORKING_STATE.md`|
| `templates/change.md`           | `.agent_files/local/changes/<id>.md` |

Team layout adds `shared/` (PROJECT_STATE, DECISION_LOG, KNOWN_RISKS, …) and
`domains/<domain>/STATE.md`. Then create `.plumblines` by hand (next section).

## The `.plumblines` config

A portable `key=value` file at the repo root, read by the shell scripts, the
PowerShell scaffolder, and CI. Environment variables of the same name override
it; the built-in defaults apply when neither is set.

```
agent_dir=.agent_files
src_globs=src/ lib/ app/ packages/
```

- `agent_dir` — where the memory tree lives (`PLUMBLINES_DIR` overrides).
- `src_globs` — space-separated pathspecs that count as "source" for the
  coverage gate (`PLUMBLINES_SRC_GLOBS` overrides). **Get this right:** the
  completeness gate only requires a change record for commits that touch these
  paths, so a wrong glob silently disables coverage.

## After setup

1. Fill `PROJECT_STATE.md` (or let the `plumblines-init` skill draft it).
2. Run `bash scripts/check-staleness.sh` and
   `bash scripts/check-completeness.sh HEAD HEAD` — both should pass.
3. Tell your agent to read `AGENT_RULES.md`, `CONTEXT_PRIORITY.md`, and
   `LOADING_POLICY.md` before changing code, and to record a change after.

See [`ci-wiring.md`](ci-wiring.md) for hook/CI detail and
[`record-schema.md`](record-schema.md) for the frontmatter contract.
