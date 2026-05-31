#!/usr/bin/env bash
# check-completeness.sh — Plumblines enforcement gate.
# CHECK 1 (coverage): every commit in a range that touched source files must
#   have a change record (matched by valid_as_of_commit).
# CHECK 2 (provenance): a record's trust cannot exceed the lowest trust among
#   its provenance inputs.
#
# Usage: scripts/check-completeness.sh [<since-ref>] [<until-ref>]
#   defaults: origin/main..HEAD
# Exit: 0 clean, 1 violations, 2 misuse/not a git repo.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=plumblines-lib.sh
source "$HERE/plumblines-lib.sh"
pl_load_config

AGENT_DIR="$PLUMBLINES_DIR"
SINCE="${1:-origin/main}"
UNTIL="${2:-HEAD}"
SRC_GLOBS="$PLUMBLINES_SRC_GLOBS"

git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo"; exit 2; }

fail=0
note() { printf '  - %s\n' "$1"; }

declare -A RECORDED=()
while IFS= read -r rec; do
  sha="$(pl_field "$rec" valid_as_of_commit || true)"
  [ -n "$sha" ] || continue
  full="$(git rev-parse --verify --quiet "${sha}^{commit}" 2>/dev/null || true)"
  [ -n "$full" ] && RECORDED["$full"]=1
done < <(pl_records "$AGENT_DIR")

echo "[1/2] Coverage: source commits in ${SINCE}..${UNTIL} must have a record"
range_ok=1
git rev-parse --verify --quiet "$SINCE" >/dev/null || {
  echo "  (skip) ref '$SINCE' not found — pass it explicitly on first run"; range_ok=0; }

if [ "$range_ok" = 1 ]; then
  mapfile -t src_commits < <(git log --format='%H' "${SINCE}..${UNTIL}" -- $SRC_GLOBS)
  if [ "${#src_commits[@]}" -eq 0 ]; then
    echo "  ok — no source-touching commits in range"
  else
    for c in "${src_commits[@]}"; do
      if [ -z "${RECORDED[$c]:-}" ]; then
        short="$(git rev-parse --short "$c")"
        subj="$(git log -1 --format='%s' "$c")"
        note "uncovered commit $short — $subj"
        fail=1
      fi
    done
    [ "$fail" = 0 ] && echo "  ok — every source commit has a change record"
  fi
fi

echo "[2/2] Provenance: record trust <= lowest input trust"
prov_fail=0
while IFS= read -r rec; do
  trust="$(pl_field "$rec" trust || true)"
  [ -n "$trust" ] || continue
  case "$trust" in needs-review|stale) continue ;; esac
  rrank="$(pl_trust_rank "$trust")"
  [ "$rrank" -lt 0 ] && continue
  lowest=99
  while IFS= read -r pt; do
    [ -n "$pt" ] || continue
    prank="$(pl_trust_rank "$pt")"
    [ "$prank" -ge 0 ] && [ "$prank" -lt "$lowest" ] && lowest="$prank"
  done < <(pl_provenance_trust "$rec")
  if [ "$lowest" -ne 99 ] && [ "$rrank" -gt "$lowest" ]; then
    note "$rec claims trust=$trust but has a lower-trust input"
    prov_fail=1; fail=1
  fi
done < <(pl_records "$AGENT_DIR")
[ "$prov_fail" = 0 ] && echo "  ok — no trust escalation found"

if [ "$fail" -ne 0 ]; then
  echo
  echo "FAIL: Plumblines completeness checks found issues above."
  echo "Add the missing change record(s) or correct the trust labels, then re-run."
  exit 1
fi
echo
echo "PASS: Plumblines completeness checks clean."
