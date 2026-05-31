---
record_type: change
id: 2026-05-31-easy-integration
valid_as_of_commit: 483f8c4151c57ebce6a98129c966a9dbc1e8ac3c
depends_on:
  - scripts/plumblines-lib.sh
  - scripts/check-completeness.sh
  - scripts/check-staleness.sh
  - scripts/plumblines-init.sh
  - scripts/plumblines-init.ps1
  - templates/obsidian/plumblines.base
  - templates/obsidian/Dashboard.md
  - skills/plumblines-init/SKILL.md
  - skills/plumblines-change/SKILL.md
  - docs/integration.md
  - docs/obsidian.md
  - .gitattributes
  - .plumblines
  - README.md
trust: needs-review
provenance:
  - { source: scripts/plumblines-lib.sh, trust: verified }
  - { source: scripts/check-completeness.sh, trust: verified }
  - { source: scripts/check-staleness.sh, trust: verified }
  - { source: scripts/plumblines-init.sh, trust: verified }
  - { source: scripts/plumblines-init.ps1, trust: verified }
  - { source: templates/obsidian/plumblines.base, trust: verified }
  - { source: docs/obsidian.md, trust: verified }
  - { source: docs/integration.md, trust: verified }
validation: passed
risks: see-body
followups: see-body
---

> **needs-review (2026-05-31):** `README.md`, `docs/integration.md`, and
> `.plumblines` were extended by the npx CLI change
> ([[2026-05-31-npx-cli]]) — the quick start now leads with npx, integration.md
> gained a section 0, and `src_globs` grew to include `cli/` and `test/`. The
> scaffolder/skills/Obsidian content below is unchanged; re-verify the doc and
> config references against current files before relying on this record.

# Make Plumblines easy to integrate, plus Obsidian support

## Metadata

Date: 2026-05-31
Agent: Claude (Opus 4.8)
Branch: feat/easy-integration
Base branch: main
Domain: tooling / docs

## Goal

Lower the barrier to adopting Plumblines. Before this change, integration was a
manual, error-prone sequence: copy 12 templates, rename them to the canonical
UPPERCASE names, choose a layout, fill blank state files, hand-edit .gitignore,
discover the env-var-only source globs, and copy CI snippets by hand. Add a
visual lens for the resulting records via Obsidian.

## Summary

Three complementary layers plus an Obsidian integration and a line-ending fix:

1. **Config** — a portable `key=value` `.plumblines` file (`agent_dir`,
   `src_globs`) read by `pl_load_config`, with precedence env > config >
   default. Both check scripts now load it. This repo's own `.plumblines` sets
   `src_globs=scripts/ docs/ templates/`, since the default matched nothing here
   and silently enforced no coverage.
2. **Scaffolder** — `plumblines-init.sh` and a behavior-matched `.ps1`. Build
   the tree (minimal or `--team`), copy templates under canonical names,
   auto-detect source globs, write `.plumblines`, patch `.gitignore`, stamp the
   current commit into state files, with optional `--hooks`/`--ci`/`--obsidian`.
   Idempotent.
3. **Agent skills** — `plumblines-init` (scaffolds then fills PROJECT_STATE.md
   from the real codebase) and `plumblines-change` (authors a gate-passing
   change record).
4. **Obsidian** — `plumblines.base` (Bases core plugin) and a Dataview
   `Dashboard.md` fallback, plus `docs/obsidian.md` covering the dot-folder
   visibility fix. `pl_records` now prunes `templates/` and `dashboards/`.
5. **Line endings** — `.gitattributes` forces `*.sh` to LF so a Windows clone
   with `core.autocrlf=true` does not break bash.

## Files Changed

| File | Change | Reason |
|---|---|---|
| `scripts/plumblines-lib.sh` | Added `pl_load_config`; pruned non-record subtrees | Config support; keep gates clean |
| `scripts/check-completeness.sh` | Load config instead of reading env directly | Single source for dir/globs |
| `scripts/check-staleness.sh` | Load config | Same |
| `scripts/plumblines-init.sh` `.ps1` | New cross-platform scaffolders | One-command setup |
| `templates/obsidian/*` | New Bases + Dataview dashboards | Visual record triage |
| `skills/*` | New init and change skills | Fill blank page; enforce gate |
| `docs/integration.md` `obsidian.md` | New docs | Install paths; Obsidian guide |
| `.gitattributes` | New | Prevent CRLF breakage on Windows |
| `.plumblines` | New | Correct coverage globs for this repo |
| `README.md` | Rewrote quick start; updated manifest | Reflect the one-command flow |

## Behaviour Before

Adoption was a ~10-step manual process; source globs were env-var-only and the
default did not match this repo; shell scripts could break on Windows clones.

## Behaviour After

`bash scripts/plumblines-init.sh` (or the `.ps1`) scaffolds a working,
gate-passing `.agent_files` tree in one command on either platform. Obsidian
users get ready-made dashboards. The completeness gate now watches this repo's
real source directories.

## Validation Summary

Dogfooded in throwaway git repos:

1. Bash scaffolder, minimal and `--team`: tree built, templates renamed, globs
   auto-detected, `.gitignore` patched, state files commit-stamped.
2. PowerShell scaffolder: same outcomes on Windows.
3. Fresh-install gates: `check-staleness.sh` and `check-completeness.sh` both
   pass immediately after init (templates/dashboards pruned, state stamped).
4. `--obsidian` / `-Obsidian`: dashboards copied to `dashboards/`; gates stay
   clean; a deliberately bad-trust comment injected into a dashboard was
   correctly ignored by the record scan.
5. Config precedence: `.plumblines` globs feed the gate; an env var overrides
   them.
6. `.gitattributes`: with `core.autocrlf=true` forced, `*.sh` checks out as LF
   (0 CRs) and bash runs clean.

## What Was Not Checked

- The Bases `.base` views were validated against the documented syntax, not run
  inside a live Obsidian 1.9+ vault.
- The agent skills were not executed end-to-end by a separate agent.

## State Update Needed?

- [x] No — PROJECT_STATE-level facts unchanged; this is additive tooling.

## Risks

- Bases dashboards are unverified in a live vault; column sorting and the
  `slice` formula may need adjustment per Obsidian version.
- Source-glob auto-detection does not include `scripts/ docs/ templates/`, so
  framework-style repos must set `src_globs` by hand (this repo now does).
- The PowerShell and bash scaffolders are behavior-matched by hand and can
  drift; there is no test asserting parity.

## Follow-ups

- Consider a tiny fixture-based test for `plumblines-lib.sh` and scaffolder
  parity.
- Validate `plumblines.base` in a real Obsidian vault and adjust if needed.
- Consider an `npx plumblines init` wrapper for the non-git-bash audience.

## Completion Check

- [x] Change record filled in
- [x] Validation recorded
- [x] Risks recorded
- [x] Follow-ups recorded
