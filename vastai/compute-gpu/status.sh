#!/usr/bin/env bash
# Show the running Vast.ai GPU instance state + rspace pool membership.
#
# Prints: instance id, actual status, GPU, $/hr, and whether the executor
# is announced in the rspace ComputeForge pool.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

if [[ -z "${VASTAI_API_KEY:-}" ]] && [[ -f ~/.secrets/private/vastai_api_key ]]; then
  VASTAI_API_KEY=$(tr -d '[:space:]' < ~/.secrets/private/vastai_api_key)
fi
: "${VASTAI_API_KEY:?set VASTAI_API_KEY}"
VAST=( vastai --api-key "$VASTAI_API_KEY" )

if [[ ! -f "$SCRIPT_DIR/.state/instance-id" ]]; then
  echo "[status] no .state/instance-id — instance not running (or up.sh state lost)"
  echo "[status] checking rspace pool anyway…"
  curl -sS https://rspace.online/api/morpheus/compute/executors | python3 -m json.tool
  exit 0
fi

INSTANCE_ID=$(cat "$SCRIPT_DIR/.state/instance-id")
EXEC_ID=$(cat "$SCRIPT_DIR/.state/executor-id")
COST=$(cat "$SCRIPT_DIR/.state/cost-per-hr")

"${VAST[@]}" show instance "$INSTANCE_ID" --raw | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  instance id:   {d.get(\"id\")}')
print(f'  status:        {d.get(\"actual_status\") or d.get(\"intended_status\")}')
print(f'  GPU:           {d.get(\"gpu_name\")} x{d.get(\"num_gpus\")}')
print(f'  \$/hr:          {d.get(\"dph_total\", \"$COST\")}')
print(f'  public addr:   {d.get(\"public_ipaddr\")}')
print(f'  executor_id:   $EXEC_ID')
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
