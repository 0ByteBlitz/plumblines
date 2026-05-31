#!/usr/bin/env bash
# plumblines-init.sh — scaffold Plumblines into a project.
# Creates the .agent_files tree, copies templates under their canonical names,
# detects source globs, writes a .plumblines config, patches .gitignore, and
# optionally installs the pre-push hook and CI workflow. Idempotent: existing
# files are left untouched and reported as skipped.
#
# Usage: scripts/plumblines-init.sh [options]
#   --team            Team/large-codebase layout (shared/ + domains/).
#   --minimal         Minimal layout (default).
#   --dir <path>      Memory directory (default: .agent_files).
#   --src-globs "<g>" Override source globs instead of auto-detecting.
#   --hooks           Install .git/hooks/pre-push completeness gate.
#   --ci              Write .github/workflows/plumblines.yml.
#   --obsidian        Drop Obsidian dashboards into <dir>/dashboards/.
#   -h, --help        Show this help.
# Exit: 0 ok, 2 misuse.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"      # the Plumblines source repo (where templates/ live)
TPL="$ROOT/templates"

LAYOUT=minimal
AGENT_DIR=".agent_files"
SRC_GLOBS=""
DO_HOOKS=0
DO_CI=0
DO_OBSIDIAN=0

usage() { sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --team)      LAYOUT=team ;;
    --minimal)   LAYOUT=minimal ;;
    --dir)       AGENT_DIR="${2:?--dir needs a value}"; shift ;;
    --src-globs) SRC_GLOBS="${2:?--src-globs needs a value}"; shift ;;
    --hooks)     DO_HOOKS=1 ;;
    --ci)        DO_CI=1 ;;
    --obsidian)  DO_OBSIDIAN=1 ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[ -d "$TPL" ] || { echo "templates/ not found next to this script ($TPL)" >&2; exit 2; }

made=0; skipped=0
mk()  { if [ -d "$1" ]; then :; else mkdir -p "$1"; echo "  + dir  $1"; fi; }
# copy <src-template> <dest>; never clobber an existing dest
cp_t() {
  local src="$1" dst="$2"
  if [ -e "$dst" ]; then echo "  = skip $dst (exists)"; skipped=$((skipped+1)); return; fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"; echo "  + file $dst"; made=$((made+1))
}

echo "Plumblines init → layout=$LAYOUT dir=$AGENT_DIR"
echo

# --- directory tree ---------------------------------------------------------
mk "$AGENT_DIR"
mk "$AGENT_DIR/local/changes"
mk "$AGENT_DIR/compacted"
mk "$AGENT_DIR/templates"
if [ "$LAYOUT" = team ]; then
  mk "$AGENT_DIR/shared"
  mk "$AGENT_DIR/domains"
fi

# --- canonical files (lowercase template -> UPPERCASE convention) -----------
cp_t "$TPL/AGENT_RULES.md"      "$AGENT_DIR/AGENT_RULES.md"
cp_t "$TPL/context-priority.md" "$AGENT_DIR/CONTEXT_PRIORITY.md"
cp_t "$TPL/loading-policy.md"   "$AGENT_DIR/LOADING_POLICY.md"
cp_t "$TPL/project-state.md"    "$AGENT_DIR/PROJECT_STATE.md"
cp_t "$TPL/working-state.md"    "$AGENT_DIR/local/WORKING_STATE.md"

if [ "$LAYOUT" = team ]; then
  cp_t "$TPL/project-state.md"  "$AGENT_DIR/shared/PROJECT_STATE.md"
  cp_t "$TPL/decisions.md"      "$AGENT_DIR/shared/DECISION_LOG.md"
  cp_t "$TPL/risks.md"          "$AGENT_DIR/shared/KNOWN_RISKS.md"
fi

# Stamp the current commit into freshly scaffolded state files so they are valid
# from birth. Only touches the COMMIT_SHA placeholder, so user-filled values stay.
HEAD_SHA="$(git rev-parse HEAD 2>/dev/null || true)"
if [ -n "$HEAD_SHA" ]; then
  for s in "$AGENT_DIR/PROJECT_STATE.md" "$AGENT_DIR/local/WORKING_STATE.md" \
           "$AGENT_DIR/shared/PROJECT_STATE.md" "$AGENT_DIR/shared/DECISION_LOG.md"; do
    [ -f "$s" ] && grep -q 'valid_as_of_commit: COMMIT_SHA' "$s" 2>/dev/null \
      && sed -i.bak "s/valid_as_of_commit: COMMIT_SHA/valid_as_of_commit: $HEAD_SHA/" "$s" \
      && rm -f "$s.bak"
  done
fi

# in-project copy of templates so future records have something to copy from
for f in "$TPL"/*.md; do
  cp_t "$f" "$AGENT_DIR/templates/$(basename "$f")"
done

# --- source-glob detection --------------------------------------------------
if [ -z "$SRC_GLOBS" ]; then
  detected=""
  for d in src lib app packages services cmd pkg internal apps source; do
    [ -d "$d" ] && detected="$detected$d/ "
  done
  SRC_GLOBS="${detected:-src/ lib/ app/ packages/}"
fi
SRC_GLOBS="$(printf '%s' "$SRC_GLOBS" | sed -E 's/[[:space:]]+$//')"
echo "  src globs: $SRC_GLOBS"

# --- .plumblines config -----------------------------------------------------
if [ -e .plumblines ]; then
  echo "  = skip .plumblines (exists)"
else
  cat > .plumblines <<EOF
# Plumblines config. Read by scripts/*.sh, the PowerShell scaffolder, and CI.
# Environment variables of the same name override these values.
agent_dir=$AGENT_DIR
src_globs=$SRC_GLOBS
EOF
  echo "  + file .plumblines"; made=$((made+1))
fi

# --- .gitignore -------------------------------------------------------------
GI_LINE="$AGENT_DIR/local/"
if [ -f .gitignore ] && grep -qxF "$GI_LINE" .gitignore; then
  echo "  = skip .gitignore ($GI_LINE already present)"
else
  printf '\n# Plumblines branch-local agent memory\n%s\n' "$GI_LINE" >> .gitignore
  echo "  + edit .gitignore (+ $GI_LINE)"
fi

# --- optional pre-push hook -------------------------------------------------
if [ "$DO_HOOKS" = 1 ]; then
  gitdir="$(git rev-parse --git-dir 2>/dev/null || true)"
  if [ -z "$gitdir" ]; then
    echo "  ! --hooks: not a git repo, skipping"
  else
    hook="$gitdir/hooks/pre-push"
    if [ -e "$hook" ]; then
      echo "  = skip $hook (exists)"
    else
      printf '#!/usr/bin/env bash\nexec scripts/check-completeness.sh origin/main HEAD\n' > "$hook"
      chmod +x "$hook"
      echo "  + file $hook"; made=$((made+1))
    fi
  fi
fi

# --- optional Obsidian dashboards -------------------------------------------
if [ "$DO_OBSIDIAN" = 1 ]; then
  if [ -d "$TPL/obsidian" ]; then
    mk "$AGENT_DIR/dashboards"
    for f in "$TPL"/obsidian/*; do
      cp_t "$f" "$AGENT_DIR/dashboards/$(basename "$f")"
    done
    echo "  Obsidian: open '$AGENT_DIR' as a vault (it's a dot-folder — see docs/obsidian.md),"
    echo "            then open dashboards/plumblines.base."
  else
    echo "  ! --obsidian: $TPL/obsidian not found, skipping"
  fi
fi

# --- optional CI workflow ---------------------------------------------------
if [ "$DO_CI" = 1 ]; then
  wf=".github/workflows/plumblines.yml"
  if [ -e "$wf" ]; then
    echo "  = skip $wf (exists)"
  else
    mkdir -p "$(dirname "$wf")"
    cat > "$wf" <<'EOF'
name: plumblines
on: pull_request
jobs:
  completeness:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Completeness gate
        run: bash scripts/check-completeness.sh origin/${{ github.base_ref }} HEAD
      - name: Staleness report (non-blocking)
        run: bash scripts/check-staleness.sh || true
EOF
    echo "  + file $wf"; made=$((made+1))
  fi
fi

echo
echo "Done. created=$made skipped=$skipped"
echo "Next:"
echo "  1. Fill $AGENT_DIR/PROJECT_STATE.md (or run the plumblines-init agent skill to draft it)."
echo "  2. Set valid_as_of_commit in PROJECT_STATE.md to: $(git rev-parse --short HEAD 2>/dev/null || echo '<commit>')"
echo "  3. Point your agent at $AGENT_DIR/AGENT_RULES.md, CONTEXT_PRIORITY.md, LOADING_POLICY.md."
