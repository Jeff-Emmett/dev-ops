#!/usr/bin/env bash
# Show the running RunPod GPU pod state.
#
# Prints: pod id, runtime status, GPU type, uptime, cost so far,
# whether it's announced in the rspace executor pool.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

if [[ -z "${RUNPOD_API_KEY:-}" ]] && [[ -f ~/.runpod/config.toml ]]; then
  RUNPOD_API_KEY=$(grep -m1 '^apikey' ~/.runpod/config.toml | sed 's/.*=[[:space:]]*//;s/"//g')
fi
: "${RUNPOD_API_KEY:?set RUNPOD_API_KEY}"

if [[ ! -f "$SCRIPT_DIR/.state/pod-id" ]]; then
  echo "[status] no .state/pod-id — pod not running (or up.sh state lost)"
  echo "[status] checking rspace pool anyway…"
  curl -sS https://rspace.online/api/morpheus/compute/executors | python3 -m json.tool
  exit 0
fi

POD_ID=$(cat "$SCRIPT_DIR/.state/pod-id")
EXEC_ID=$(cat "$SCRIPT_DIR/.state/executor-id")
COST=$(cat "$SCRIPT_DIR/.state/cost-per-hr")

POD_INFO=$(curl -fsS -X POST https://api.runpod.io/graphql \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
  -d "{\"query\":\"query { pod(input: { podId: \\\"$POD_ID\\\" }) { id desiredStatus lastStatusChange runtime { uptimeInSeconds } machine { gpuDisplayName } } }\"}")

echo "$POD_INFO" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())['data']['pod']
runtime = d.get('runtime') or {}
print(f'  pod id:        {d[\"id\"]}')
print(f'  status:        {d.get(\"desiredStatus\")}')
print(f'  GPU:           {d.get(\"machine\", {}).get(\"gpuDisplayName\")}')
print(f'  uptime:        {runtime.get(\"uptimeInSeconds\", \"booting\")}s')
print(f'  executor_id:   $EXEC_ID')
print(f'  cost so far:   \$' + str(round((runtime.get('uptimeInSeconds', 0) or 0) / 3600 * float('$COST'), 4)))
"

echo "  --- rspace pool ---"
curl -sS https://rspace.online/api/morpheus/compute/executors | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
found = False
for e in d['executors']:
    flag = '*' if e['executorId'] == '$EXEC_ID' else ' '
    print(f'  {flag} {e[\"executorId\"]}  ({len(e[\"computeForms\"])} forms, heartbeat {e[\"health\"][\"lastHeartbeat\"]})')
    if e['executorId'] == '$EXEC_ID':
        found = True
if not found:
    print(f'    ✗ $EXEC_ID NOT in rspace pool (announce may still be pending)')
"
