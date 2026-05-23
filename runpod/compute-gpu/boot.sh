#!/usr/bin/env bash
# RunPod boot script for compute-gpu (TASK-346.7).
#
# Brings up Tailscale, builds + runs docker/compute-gpu from the
# rspace-online repo, exports announce env vars, watches the
# announce loop. Logs to /workspace/compute-gpu.log.
#
# Required env (set in RunPod template):
#   TAILSCALE_AUTHKEY              ephemeral auth key with tag:runpod
#   RSPACE_ANNOUNCE_URL            http://<rspace-tailscale-ip>:3000/api/morpheus/compute/executors/announce
#   COMPUTE_GPU_EXECUTOR_ID        rspace.runpod.gpu-<unique>
#   COMPUTE_GPU_LOCALITY_HOST      runpod-<unique>
#   COMPUTE_GPU_VRAM_MB            per-GPU VRAM in MB (e.g. 24576)
#
# Optional env:
#   GITEA_TOKEN                    pull rspace-online repo if private
#   IMAGE_TAG                      pre-built image tag (skips local build)

set -euo pipefail

LOG=/workspace/compute-gpu.log
exec >"$LOG" 2>&1

echo "[boot] $(date -u +%FT%TZ) starting compute-gpu boot"
echo "[boot] EXECUTOR_ID=$COMPUTE_GPU_EXECUTOR_ID"
echo "[boot] LOCALITY_HOST=$COMPUTE_GPU_LOCALITY_HOST"

# ── Tailscale up ───────────────────────────────────────────────────
echo "[boot] joining Tailscale"
tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state &
sleep 3
tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname="$COMPUTE_GPU_EXECUTOR_ID" --accept-routes
echo "[boot] Tailscale IP: $(tailscale ip -4)"

# ── Pull / build image ─────────────────────────────────────────────
if [[ -n "${IMAGE_TAG:-}" ]]; then
  echo "[boot] using pre-built image: rspace/compute-gpu:$IMAGE_TAG"
  docker pull "localhost:3000/rspace/compute-gpu:$IMAGE_TAG"
  IMAGE="localhost:3000/rspace/compute-gpu:$IMAGE_TAG"
else
  echo "[boot] cloning rspace-online + building locally"
  cd /workspace
  if [[ -n "${GITEA_TOKEN:-}" ]]; then
    git clone "https://oauth2:$GITEA_TOKEN@gitea.jeffemmett.com/jeffemmett/rspace-online.git" || true
  else
    git clone https://gitea.jeffemmett.com/jeffemmett/rspace-online.git || true
  fi
  cd rspace-online/docker/compute-gpu
  docker build -t rspace/compute-gpu:local .
  IMAGE="rspace/compute-gpu:local"
fi

# ── Run executor ────────────────────────────────────────────────────
echo "[boot] starting compute-gpu container"
docker run -d --restart=always --name compute-gpu \
  --gpus all \
  -p 9101:9101 \
  -e COMPUTE_GPU_PORT=9101 \
  -e COMPUTE_GPU_EXECUTOR_ID="$COMPUTE_GPU_EXECUTOR_ID" \
  -e COMPUTE_GPU_HOST="$COMPUTE_GPU_LOCALITY_HOST" \
  -e COMPUTE_GPU_LOCALITY_HOST="$COMPUTE_GPU_LOCALITY_HOST" \
  -e COMPUTE_GPU_VRAM_MB="$COMPUTE_GPU_VRAM_MB" \
  -e RSPACE_ANNOUNCE_URL="$RSPACE_ANNOUNCE_URL" \
  "$IMAGE"

echo "[boot] container started — tailing announce log"
docker logs -f compute-gpu
