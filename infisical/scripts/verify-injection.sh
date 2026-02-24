#!/bin/bash
# Verify Infisical secret injection for deployed containers
# Usage: ./verify-injection.sh [ssh-host] [container-name-filter]
#
# Checks container logs for "[infisical]" messages to confirm injection worked.

set -euo pipefail

SSH_HOST="${1:-netcup}"
FILTER="${2:-}"

echo "=== Verifying Infisical injection on ${SSH_HOST} ==="
echo ""

if [ -n "$FILTER" ]; then
  CONTAINERS=$(ssh "$SSH_HOST" "docker ps --format '{{.Names}}' | grep -i '${FILTER}' || true")
else
  # Find containers that have INFISICAL env vars
  CONTAINERS=$(ssh "$SSH_HOST" "
    docker ps --format '{{.Names}}' | while read -r name; do
      if docker inspect \"\$name\" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -q 'INFISICAL_CLIENT_ID'; then
        echo \"\$name\"
      fi
    done
  ")
fi

if [ -z "$CONTAINERS" ]; then
  echo "No containers found with Infisical integration"
  exit 0
fi

PASS=0
FAIL=0
WARN=0

while IFS= read -r container; do
  [ -z "$container" ] && continue

  # Check last 50 lines of logs for infisical messages
  LOGS=$(ssh "$SSH_HOST" "docker logs --tail 50 '${container}' 2>&1 | grep -i 'infisical' || true")

  if echo "$LOGS" | grep -q "Injected.*secrets"; then
    COUNT=$(echo "$LOGS" | grep -oP 'Injected \K[0-9]+' | tail -1)
    echo "  PASS: ${container} (${COUNT} secrets injected)"
    PASS=$((PASS + 1))
  elif echo "$LOGS" | grep -q "No credentials set"; then
    echo "  WARN: ${container} (no credentials configured)"
    WARN=$((WARN + 1))
  elif echo "$LOGS" | grep -qi "failed\|error\|warning"; then
    echo "  FAIL: ${container}"
    echo "$LOGS" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  else
    echo "  UNKNOWN: ${container} (no infisical log messages found)"
    WARN=$((WARN + 1))
  fi
done <<< "$CONTAINERS"

echo ""
echo "=== Results ==="
echo "  Pass: ${PASS}"
echo "  Fail: ${FAIL}"
echo "  Warn: ${WARN}"

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
