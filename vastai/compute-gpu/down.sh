#!/usr/bin/env bash
# Tear down the running Vast.ai GPU executor.
#
# Reads instance id from .state/instance-id (written by up.sh). Pass `--all`
# to destroy ALL instances labelled rspace-compute-gpu in your account
# (useful if the state file drifted).
#
# Mirrors dev-ops/runpod/compute-gpu/down.sh. We first ask rspace to drain
# the executor (mark-dead → RebindTrigger migration) before destroying, so
# in-flight plans rebind instead of erroring.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LABEL="rspace-compute-gpu"

if [[ -z "${VASTAI_API_KEY:-}" ]] && [[ -f ~/.secrets/private/vastai_api_key ]]; then
  VASTAI_API_KEY=$(tr -d '[:space:]' < ~/.secrets/private/vastai_api_key)
fi
: "${VASTAI_API_KEY:?set VASTAI_API_KEY or populate ~/.secrets/private/vastai_api_key}"
VAST=( vastai --api-key "$VASTAI_API_KEY" )

DRAIN_BASE="${RSPACE_ANNOUNCE_URL:-https://rspace.online/api/morpheus/compute/executors/announce}"
DRAIN_BASE="${DRAIN_BASE%/announce}"

drain_executor() {
  local exec_id="$1"
  [[ -z "$exec_id" ]] && return 0
  echo "[down] draining $exec_id (mark-dead)"
  curl -fsS -X POST "${DRAIN_BASE}/${exec_id}/mark-dead" \
    -H "Authorization: Bearer ${COMPUTE_EXECUTOR_TOKEN:-}" >/dev/null 2>&1 || true
}

destroy_instance() {
  local id="$1"
  echo "[down] destroying instance $id"
  "${VAST[@]}" destroy instance "$id" --raw >/dev/null
}

if [[ "${1:-}" == "--all" ]]; then
  echo "[down] enumerating all '$LABEL' instances"
  "${VAST[@]}" show instances --raw | python3 -c '
import sys, json
for i in json.load(sys.stdin):
    if (i.get("label") or "").startswith("'"$LABEL"'"):
        print(i["id"])
' | while read -r id; do
    [[ -n "$id" ]] && destroy_instance "$id"
  done
  rm -rf "$SCRIPT_DIR/.state"
  exit 0
fi

if [[ ! -f "$SCRIPT_DIR/.state/instance-id" ]]; then
  echo "[down] no .state/instance-id — nothing to do. Use --all to clear stragglers."
  exit 0
fi

INSTANCE_ID=$(cat "$SCRIPT_DIR/.state/instance-id")
[[ -f "$SCRIPT_DIR/.state/executor-id" ]] && drain_executor "$(cat "$SCRIPT_DIR/.state/executor-id")"
sleep 2
destroy_instance "$INSTANCE_ID"
rm -rf "$SCRIPT_DIR/.state"
echo "[down] done"
