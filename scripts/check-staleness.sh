#!/usr/bin/env bash
# check-staleness.sh — flag records whose dependencies moved since their commit.
# Usage: scripts/check-staleness.sh
# Exit:  0 nothing stale, 1 stale found, 2 not a git repo.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=plumblines-lib.sh
source "$HERE/plumblines-lib.sh"
pl_load_config

AGENT_DIR="$PLUMBLINES_DIR"
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo"; exit 2; }

stale=0
echo "Staleness scan (depends_on changed since valid_as_of_commit)"

while IFS= read -r rec; do
  sha="$(pl_field "$rec" valid_as_of_commit || true)"
  [ -n "$sha" ] || continue
  full="$(git rev-parse --verify --quiet "${sha}^{commit}" 2>/dev/null || true)"
  if [ -z "$full" ]; then
    printf '  ? %s — valid_as_of_commit %s not found in history\n' "$rec" "$sha"
    stale=1; continue
  fi
  mapfile -t deps < <(pl_list "$rec" depends_on)
  [ "${#deps[@]}" -eq 0 ] && continue
  changed="$(git diff --name-only "${full}..HEAD" -- "${deps[@]}" 2>/dev/null || true)"
  if [ -n "$changed" ]; then
    trust="$(pl_field "$rec" trust || echo '?')"
    printf '  ! %s (trust=%s) — dependencies changed since %s:\n' \
      "$rec" "$trust" "$(git rev-parse --short "$full")"
    while IFS= read -r f; do printf '      %s\n' "$f"; done <<< "$changed"
    stale=1
  fi
done < <(pl_records "$AGENT_DIR")

if [ "$stale" -ne 0 ]; then
  echo
  echo "Review the records above and re-label as needs-review or update them."
  exit 1
fi
echo "  ok — no stale records detected."
