#!/usr/bin/env bash
# Spin up a Vast.ai GPU executor for Compute-Morpheus.
#
# Secondary burst tier — Vast.ai undercuts RunPod ~20-40% on $/hr at the
# A5000/4090/L4/A100 class this executor uses. Dispatch in rspace
# (shared/morpheus/forges/compute-forge.ts) cost-ranks every announced
# executor, so a cheaper Vast executor automatically wins routing — no
# router change. This is the Vast analogue of dev-ops/runpod/compute-gpu/up.sh.
#
# Usage:  ./up.sh [GPU_NAME] [MAX_DPH]
#         GPU_NAME  Vast gpu_name filter (default RTX_4090)
#         MAX_DPH   max $/hr to bid             (default 0.35)
#
# Requires:
#   ~/.secrets/private/vastai_api_key   (or $VASTAI_API_KEY)
#   $TAILSCALE_AUTHKEY                   ephemeral key tagged tag:vastai
#   $COMPUTE_EXECUTOR_TOKEN              else pulled from rspace/prod Infisical
#
# The instance runs the pre-baked ghcr.io executor image directly; the
# Vast on-start (boot.sh) adds Tailscale + sets COMPUTE_GPU_PUBLIC_ENDPOINT.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
GPU_NAME="${1:-RTX_4090}"
MAX_DPH="${2:-0.35}"
IMAGE="ghcr.io/jeff-emmett/rspace-compute-gpu:latest"
LABEL="rspace-compute-gpu"
ANNOUNCE_URL="${RSPACE_ANNOUNCE_URL:-https://rspace.online/api/morpheus/compute/executors/announce}"

# ── Vast API key ───────────────────────────────────────────────────
if [[ -z "${VASTAI_API_KEY:-}" ]] && [[ -f ~/.secrets/private/vastai_api_key ]]; then
  VASTAI_API_KEY=$(tr -d '[:space:]' < ~/.secrets/private/vastai_api_key)
fi
: "${VASTAI_API_KEY:?set VASTAI_API_KEY or populate ~/.secrets/private/vastai_api_key}"
VAST=( vastai --api-key "$VASTAI_API_KEY" )

# ── Tailscale auth key (Vast has no provider proxy → callback over tailnet) ──
: "${TAILSCALE_AUTHKEY:?set TAILSCALE_AUTHKEY (ephemeral, tag:vastai) — rspace must reach the executor over the tailnet}"

# ── Executor token from Infisical (netcup) — reused verbatim from runpod up.sh ──
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

# ── Find the cheapest reliable offer ───────────────────────────────
echo "[up] searching Vast offers: ${GPU_NAME} num_gpus=1 reliability>0.98 dph<${MAX_DPH}"
OFFERS=$("${VAST[@]}" search offers \
  "gpu_name=${GPU_NAME} num_gpus=1 reliability>0.98 inet_down>200 disk_space>30 cuda_max_good>=12.4 rentable=true dph<${MAX_DPH}" \
  -o 'dph' --raw)

read -r OFFER_ID DPH VRAM_MB <<<"$(echo "$OFFERS" | python3 -c '
import sys, json
offers = json.load(sys.stdin)
if not offers:
    sys.exit("__none__")
o = offers[0]  # already sorted ascending by dph
print(o["id"], round(o["dph_total"], 4), int(o.get("gpu_ram", 24576)))
' 2>/dev/null)" || { echo "[up] no offers matched (try a higher MAX_DPH or different GPU_NAME)"; exit 1; }

[[ -z "${OFFER_ID:-}" ]] && { echo "[up] no matching Vast offer for ${GPU_NAME} under \$${MAX_DPH}/hr"; exit 1; }
echo "[up] selected offer $OFFER_ID @ \$${DPH}/hr  (${VRAM_MB}MB VRAM)"

# ── Identity + env ─────────────────────────────────────────────────
EXEC_ID="rspace.vastai.gpu-$(date +%s)"
ENV_STR="-e COMPUTE_EXECUTOR_TOKEN=${COMPUTE_EXECUTOR_TOKEN}"
ENV_STR+=" -e COMPUTE_GPU_EXECUTOR_ID=${EXEC_ID}"
ENV_STR+=" -e COMPUTE_GPU_LOCALITY_HOST=vastai-${OFFER_ID}"
ENV_STR+=" -e COMPUTE_GPU_VRAM_MB=${VRAM_MB}"
ENV_STR+=" -e TAILSCALE_AUTHKEY=${TAILSCALE_AUTHKEY}"
ENV_STR+=" -e RSPACE_ANNOUNCE_URL=${ANNOUNCE_URL}"
ENV_STR+=" -p 9101:9101"

# ── Create the instance (on-start = boot.sh, embedded so no file upload) ──
echo "[up] creating Vast instance from $IMAGE"
RESPONSE=$("${VAST[@]}" create instance "$OFFER_ID" \
  --image "$IMAGE" \
  --disk 30 \
  --label "$LABEL" \
  --env "$ENV_STR" \
  --onstart-cmd "$(cat "$SCRIPT_DIR/boot.sh")" \
  --raw)

INSTANCE_ID=$(echo "$RESPONSE" | python3 -c 'import sys,json; d=json.loads(sys.stdin.read()); print(d.get("new_contract") or "")' 2>/dev/null || true)
if [[ -z "$INSTANCE_ID" ]]; then
  echo "[up] create failed:"; echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
  exit 1
fi
echo "[up] instance $INSTANCE_ID created (exec $EXEC_ID) @ \$${DPH}/hr"

# ── Save state for down.sh + status.sh ─────────────────────────────
mkdir -p "$SCRIPT_DIR/.state"
echo "$INSTANCE_ID" > "$SCRIPT_DIR/.state/instance-id"
echo "$EXEC_ID"     > "$SCRIPT_DIR/.state/executor-id"
echo "$DPH"         > "$SCRIPT_DIR/.state/cost-per-hr"

# ── Wait for announce (boot installs Tailscale → slower than RunPod) ──
echo "[up] waiting for announce to rspace (Tailscale install adds ~30-60s)…"
DEADLINE=$(( $(date +%s) + 420 ))
while [[ $(date +%s) -lt $DEADLINE ]]; do
  if curl -fsS "${ANNOUNCE_URL%/announce}" 2>/dev/null | grep -q "$EXEC_ID"; then
    echo "[up] ✓ $EXEC_ID announced + visible in pool"
    "$SCRIPT_DIR/status.sh"
    exit 0
  fi
  sleep 15
  echo "[up] waiting… ($(($DEADLINE - $(date +%s)))s remaining)"
done

echo "[up] WARN: instance up but no announce after 7min."
echo "[up]   Check on-start log: ${VAST[*]} logs $INSTANCE_ID"
echo "[up]   Common causes: offer blocks userspace Tailscale, or image pull slow."
exit 2
