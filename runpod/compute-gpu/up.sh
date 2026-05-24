#!/usr/bin/env bash
# Spin up a RunPod GPU executor for Compute-Morpheus.
#
# Usage:  ./up.sh [gpu-type]   (default: NVIDIA RTX A5000)
# Cost:   ~$0.16/hr A5000, ~$0.34/hr RTX 4090, ~$0.44/hr L4
#
# Requires:
#   $RUNPOD_API_KEY                  (or ~/.runpod/config.toml)
#   $COMPUTE_EXECUTOR_TOKEN          pulled below from rspace/prod Infisical
#
# The pod uses the pre-baked ghcr.io image — no apt/pip at boot.
# Image must be PUBLIC (one-time web-UI flip at
# github.com/users/Jeff-Emmett/packages/container/rspace-compute-gpu/settings).
#
# Behaviour:
#   - Mints a unique executor ID per session
#   - Pod CMD = `python3 server.py` (just the executor)
#   - Pod announces to rspace.online via bearer token gate
#   - Idle pods can be torn down via down.sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
GPU_TYPE="${1:-NVIDIA RTX A5000}"
IMAGE="ghcr.io/jeff-emmett/rspace-compute-gpu:latest"
ANNOUNCE_URL="${RSPACE_ANNOUNCE_URL:-https://rspace.online/api/morpheus/compute/executors/announce}"

# ── API key ────────────────────────────────────────────────────────
if [[ -z "${RUNPOD_API_KEY:-}" ]] && [[ -f ~/.runpod/config.toml ]]; then
  RUNPOD_API_KEY=$(grep -m1 '^apikey' ~/.runpod/config.toml | sed 's/.*=[[:space:]]*//;s/"//g')
fi
: "${RUNPOD_API_KEY:?set RUNPOD_API_KEY or configure ~/.runpod/config.toml}"

# ── Executor token from Infisical (netcup) ─────────────────────────
if [[ -z "${COMPUTE_EXECUTOR_TOKEN:-}" ]]; then
  echo "[up] fetching COMPUTE_EXECUTOR_TOKEN from Infisical rspace/prod"
  COMPUTE_EXECUTOR_TOKEN=$(ssh netcup-full '
    set -a; . /opt/rspace-online/.env; set +a
    docker exec -e CID="$INFISICAL_CLIENT_ID" -e CSEC="$INFISICAL_CLIENT_SECRET" infisical sh -c "
      AT=\$(curl -fsS -X POST http://localhost:8080/api/v1/auth/universal-auth/login \
        -H Content-Type:application/json \
        -d \"{\\\"clientId\\\":\\\"\$CID\\\",\\\"clientSecret\\\":\\\"\$CSEC\\\"}\" | grep -oE \"\\\"accessToken\\\":\\\"[^\\\"]+\\\"\" | sed \"s/.*\\\"accessToken\\\":\\\"//;s/\\\"//g\")
      curl -fsS \"http://localhost:8080/api/v3/secrets/raw?workspaceSlug=rspace&environment=prod&secretPath=/&recursive=false\" \
        -H \"Authorization: Bearer \$AT\"
    " | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(next(s[\"secretValue\"] for s in d[\"secrets\"] if s[\"secretKey\"]==\"COMPUTE_EXECUTOR_TOKEN\"))"
  ')
fi
: "${COMPUTE_EXECUTOR_TOKEN:?failed to fetch token from Infisical}"

# ── Build mutation ─────────────────────────────────────────────────
EXEC_ID="rspace.runpod.gpu-$(date +%s)"
GPU_SLUG=$(echo "$GPU_TYPE" | tr 'A-Z ' 'a-z-' | sed 's/nvidia-//')

cat > /tmp/runpod-up.json <<EOF
{
  "query": "mutation Deploy(\$input: PodFindAndDeployOnDemandInput!) { podFindAndDeployOnDemand(input: \$input) { id machineId desiredStatus costPerHr } }",
  "variables": {
    "input": {
      "cloudType": "COMMUNITY",
      "gpuCount": 1,
      "gpuTypeId": "${GPU_TYPE}",
      "name": "rspace-compute-gpu-${EXEC_ID##*.}",
      "imageName": "${IMAGE}",
      "containerDiskInGb": 25,
      "minVcpuCount": 4,
      "minMemoryInGb": 16,
      "ports": "9101/http",
      "env": [
        {"key": "COMPUTE_EXECUTOR_TOKEN", "value": "${COMPUTE_EXECUTOR_TOKEN}"},
        {"key": "COMPUTE_GPU_EXECUTOR_ID", "value": "${EXEC_ID}"},
        {"key": "COMPUTE_GPU_LOCALITY_HOST", "value": "${GPU_SLUG}"},
        {"key": "COMPUTE_GPU_VRAM_MB", "value": "24576"},
        {"key": "COMPUTE_GPU_HOST", "value": "0.0.0.0"},
        {"key": "RSPACE_ANNOUNCE_URL", "value": "${ANNOUNCE_URL}"}
      ]
    }
  }
}
EOF

# ── Deploy ─────────────────────────────────────────────────────────
echo "[up] deploying ${GPU_TYPE} pod with image ${IMAGE}"
RESPONSE=$(curl -fsS -X POST https://api.runpod.io/graphql \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
  -d @/tmp/runpod-up.json)

POD_ID=$(echo "$RESPONSE" | python3 -c 'import sys,json; print(json.loads(sys.stdin.read())["data"]["podFindAndDeployOnDemand"]["id"])' 2>/dev/null || true)

if [[ -z "$POD_ID" ]]; then
  echo "[up] deploy failed:"
  echo "$RESPONSE" | python3 -m json.tool
  exit 1
fi

COST=$(echo "$RESPONSE" | python3 -c 'import sys,json; print(json.loads(sys.stdin.read())["data"]["podFindAndDeployOnDemand"]["costPerHr"])')
echo "[up] pod $POD_ID up at \$${COST}/hr"
echo "[up] executor_id: $EXEC_ID"

# Save state for down.sh + status.sh
mkdir -p "$SCRIPT_DIR/.state"
echo "$POD_ID" > "$SCRIPT_DIR/.state/pod-id"
echo "$EXEC_ID" > "$SCRIPT_DIR/.state/executor-id"
echo "$COST" > "$SCRIPT_DIR/.state/cost-per-hr"

# ── Wait for announce ──────────────────────────────────────────────
echo "[up] waiting for announce to rspace…"
DEADLINE=$(( $(date +%s) + 300 ))
while [[ $(date +%s) -lt $DEADLINE ]]; do
  if curl -fsS "${ANNOUNCE_URL%/announce}" 2>/dev/null | grep -q "$EXEC_ID"; then
    echo "[up] ✓ $EXEC_ID announced + visible in pool"
    "$SCRIPT_DIR/status.sh"
    exit 0
  fi
  sleep 15
  echo "[up] waiting… ($(($DEADLINE - $(date +%s)))s remaining)"
done

echo "[up] WARN: pod up but no announce after 5min; check ./status.sh + RunPod web logs"
exit 2
