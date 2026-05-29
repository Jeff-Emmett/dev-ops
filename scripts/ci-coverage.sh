#!/usr/bin/env bash
# ci-coverage.sh — regenerate the CI/CD coverage inventory.
#
# Walks ~/Github, classifies each local repo as has-CI / no-CI-deployable /
# no-CI-skip, and emits a list ordered by last-commit recency. Feeds
# dev-ops/CI-COVERAGE.md.
#
# Usage: bash ci-coverage.sh [GITHUB_ROOT]
#   GITHUB_ROOT defaults to ~/Github

set -uo pipefail
# Do NOT set -e: find failures on missing .gitea/workflows dirs are
# intentional (the whole point is to detect missing CI).

ROOT="${1:-$HOME/Github}"
cd "$ROOT"

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

for d in */; do
  d=${d%/}
  [ ! -d "$d/.git" ] && continue

  ci=$(find "$d/.gitea/workflows" -maxdepth 1 -name '*.yml' 2>/dev/null | head -1)
  cmp=$(find "$d" -maxdepth 2 \
      \( -name 'docker-compose*.yml' -o -name 'Dockerfile' \) \
      -not -path '*/node_modules/*' 2>/dev/null | head -1)
  age=$(git -C "$d" log -1 --format=%cr 2>/dev/null || echo 'no commits')

  if [ -n "$ci" ]; then
    status='has-ci'
  elif [ -n "$cmp" ]; then
    status='no-ci-deployable'
  else
    status='no-ci-skip'
  fi
  printf "%-32s | %-22s | %s\n" "$age" "$status" "$d" >> "$TMP"
done

printf "%-32s | %-22s | %s\n" "RECENCY" "STATUS" "REPO"
printf '%s\n' "$(printf '%.0s-' {1..96})"
sort "$TMP"
printf '%s\n' "$(printf '%.0s-' {1..96})"

has_ci=$(grep -c "| has-ci " "$TMP" || true)
no_ci_dep=$(grep -c "| no-ci-deployable " "$TMP" || true)
no_ci_skip=$(grep -c "| no-ci-skip " "$TMP" || true)
total=$((has_ci + no_ci_dep + no_ci_skip))
printf "Summary: %d has-ci, %d no-ci-deployable, %d no-ci-skip, %d total\n" \
  "$has_ci" "$no_ci_dep" "$no_ci_skip" "$total"
