#!/usr/bin/env bash
# Tear down the running RunPod GPU executor.
#
# Reads pod id from .state/pod-id (written by up.sh). Pass `--all` to
# terminate ALL rspace-compute-gpu* pods in your account (useful if the
# state file got out of sync).

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

if [[ -z "${RUNPOD_API_KEY:-}" ]] && [[ -f ~/.runpod/config.toml ]]; then
  RUNPOD_API_KEY=$(grep -m1 '^apikey' ~/.runpod/config.toml | sed 's/.*=[[:space:]]*//;s/"//g')
fi
: "${RUNPOD_API_KEY:?set RUNPOD_API_KEY or configure ~/.runpod/config.toml}"

terminate_pod() {
  local pod_id="$1"
  echo "[down] terminating pod $pod_id"
  curl -fsS -X POST https://api.runpod.io/graphql \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
    -d "{\"query\":\"mutation { podTerminate(input: { podId: \\\"$pod_id\\\" }) }\"}" \
    >/dev/null
}

if [[ "${1:-}" == "--all" ]]; then
  echo "[down] enumerating all rspace-compute-gpu pods"
  curl -fsS -X POST https://api.runpod.io/graphql \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
    -d '{"query":"query { myself { pods { id name desiredStatus } } }"}' | \
    python3 -c '
import sys, json
d = json.loads(sys.stdin.read())
pods = d.get("data", {}).get("myself", {}).get("pods") or []
for p in pods:
    if p["name"].startswith("rspace-compute-gpu"):
        print(p["id"])
' | while read -r id; do
    [[ -n "$id" ]] && terminate_pod "$id"
  done
  rm -rf "$SCRIPT_DIR/.state"
  exit 0
fi

if [[ ! -f "$SCRIPT_DIR/.state/pod-id" ]]; then
  echo "[down] no .state/pod-id — nothing to do. Use --all to clear stragglers."
  exit 0
fi

POD_ID=$(cat "$SCRIPT_DIR/.state/pod-id")
terminate_pod "$POD_ID"
rm -rf "$SCRIPT_DIR/.state"
echo "[down] done"
