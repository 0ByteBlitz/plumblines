#!/usr/bin/env bash
# plumblines-lib.sh — shared helpers. Sourced by the check scripts.
# Pure bash + git. No yq/jq dependency so it runs anywhere git does.

# Extract the YAML frontmatter block (between the first two `---` lines) of a file.
pl_frontmatter() {
  awk '
    NR==1 && $0!="---" { exit }
    NR==1 { infm=1; next }
    infm && $0=="---" { exit }
    infm { print }
  ' "$1"
}

# Read a scalar field: pl_field <file> <key>
pl_field() {
  pl_frontmatter "$1" | awk -v k="$2" '
    $0 ~ "^"k":" {
      sub("^"k":[ \t]*", "")
      gsub(/^["\x27]|["\x27]$/, "")
      print
      exit
    }'
}

# Read a YAML block list into newline-separated values: pl_list <file> <key>
pl_list() {
  pl_frontmatter "$1" | awk -v k="$2" '
    $0 ~ "^"k":[ \t]*$" { inlist=1; next }
    inlist && /^[ \t]+-[ \t]*/ {
      sub(/^[ \t]+-[ \t]*/, ""); gsub(/^["\x27]|["\x27]$/, ""); print; next
    }
    inlist && /^[^ \t]/ { exit }
  '
}

# Read provenance trust levels (the `trust:` inside each `- { ... }` item).
pl_provenance_trust() {
  pl_frontmatter "$1" | awk '
    /^provenance:/ { inp=1; next }
    inp && /trust:[ \t]*[A-Za-z-]+/ {
      match($0, /trust:[ \t]*[A-Za-z-]+/)
      s=substr($0, RSTART, RLENGTH); sub(/trust:[ \t]*/, "", s); print s; next
    }
    inp && /^[^ \t-]/ { exit }
  '
}

# Numeric rank for trust ordering (higher = more trusted). Unknown -> -1.
pl_trust_rank() {
  case "$1" in
    verified) echo 3 ;;
    inferred) echo 2 ;;
    assumed)  echo 1 ;;
    *)        echo -1 ;;
  esac
}

# All Plumblines record files under .agent_files.
# Prune non-record subtrees: `templates/` holds blank scaffolds (COMMIT_SHA
# placeholders, dummy provenance) and `dashboards/` holds Obsidian views —
# neither are records, so they must never trip the checks.
pl_records() {
  local root="${1:-.agent_files}"
  find "$root" \( -type d \( -name templates -o -name dashboards \) -prune \) \
    -o -type f -name '*.md' -print 2>/dev/null
}

# Load .plumblines config into PLUMBLINES_DIR / PLUMBLINES_SRC_GLOBS.
# Precedence: existing environment variable > config file > built-in default.
# Config format is simple `key=value` lines (`#` comments), so the same file
# is parseable by bash, PowerShell, and node without a YAML dependency.
pl_load_config() {
  local cfg="${PLUMBLINES_CONFIG:-.plumblines}"
  local dir_cfg="" globs_cfg="" line key val
  if [ -f "$cfg" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in ''|\#*) continue ;; esac
      key="${line%%=*}"; val="${line#*=}"
      # trim surrounding whitespace and optional quotes
      key="$(printf '%s' "$key" | awk '{$1=$1};1')"
      val="$(printf '%s' "$val" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^["'\'']//; s/["'\'']$//')"
      case "$key" in
        agent_dir)  dir_cfg="$val" ;;
        src_globs)  globs_cfg="$val" ;;
      esac
    done < "$cfg"
  fi
  PLUMBLINES_DIR="${PLUMBLINES_DIR:-${dir_cfg:-.agent_files}}"
  PLUMBLINES_SRC_GLOBS="${PLUMBLINES_SRC_GLOBS:-${globs_cfg:-src/ lib/ app/ packages/}}"
  export PLUMBLINES_DIR PLUMBLINES_SRC_GLOBS
}
