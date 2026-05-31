# Changelog

All notable changes to Plumblines are recorded here. The framework itself is
plain Markdown; this file tracks the tooling and structure around it.

## 0.3.0 — 2026-05-31

Focus: make Plumblines easy to adopt, and add an npx distribution path.

### Added
- **Cross-platform scaffolder** — `scripts/plumblines-init.sh` and a
  behavior-matched `plumblines-init.ps1`. One command builds the `.agent_files`
  tree (minimal or `--team`), copies templates under their canonical names,
  auto-detects source globs, writes `.plumblines`, patches `.gitignore`, stamps
  the current commit into state files, with optional `--hooks`/`--ci`/`--obsidian`.
- **`.plumblines` config** — portable `key=value` file (`agent_dir`,
  `src_globs`) read by the check scripts and the CLI. Precedence: env > config >
  default.
- **Agent skills** — `plumblines-init` (scaffolds, then fills `PROJECT_STATE.md`
  from the real codebase) and `plumblines-change` (authors a gate-passing change
  record).
- **Obsidian integration** — `templates/obsidian/plumblines.base` (Bases core
  plugin) and a Dataview `Dashboard.md` fallback, plus `docs/obsidian.md`.
- **npx CLI** (`cli/`) — dependency-free Node implementation of `init` and both
  gates: `npx plumblines init` and `npx plumblines check`. Works with nothing
  checked out (`npx github:0ByteBlitz/plumblines init`).
- **Tests** — `test/cli.test.js`, including byte-for-byte parity between the Node
  and shell gates.
- **CI** — `.github/workflows/plumblines.yml` runs the completeness gate,
  staleness report, and the CLI/parity tests.
- **`docs/integration.md`** — install paths and the manual-copy name mapping.

### Changed
- `pl_records` prunes `templates/` and `dashboards/` so non-record files never
  trip the gates.
- README quick start rewritten around the one-command flow; trimmed duplication.
- `.gitattributes` forces `*.sh` to LF (Windows clones) and `*.js`/`*.json` to
  LF (so the published bin's shebang works on Linux/macOS).

## 0.2.1 — 2026-05-27

- Enforcement gate (`check-completeness.sh`), shared frontmatter parser
  (`plumblines-lib.sh`), YAML frontmatter record schema, and CI/hook wiring.
- See `docs/v0.2-upgrade-notes.md` for the 0.2 line.
