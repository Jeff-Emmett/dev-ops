#!/usr/bin/env bash
# RunPod boot script for compute-gpu (TASK-346.7).
#
# Clones rspace-online, builds docker/compute-gpu, runs --gpus all,
# announces to rspace via the public URL (bearer-token auth — set
# COMPUTE_EXECUTOR_TOKEN in the RunPod template env).
#
# Tailscale path is OPTIONAL (set TAILSCALE_AUTHKEY to join the tailnet
# and use the rspace internal URL instead of the public Cloudflare one).
#
# Required env (set in RunPod template):
#   COMPUTE_EXECUTOR_TOKEN         shared secret matching rspace/prod
#   COMPUTE_GPU_EXECUTOR_ID        rspace.runpod.gpu-<unique>
#   COMPUTE_GPU_LOCALITY_HOST      runpod-<unique>
#   COMPUTE_GPU_VRAM_MB            per-GPU VRAM in MB (e.g. 24576)
#
# Optional env:
#   RSPACE_ANNOUNCE_URL            override; default https://rspace.online/...
#   TAILSCALE_AUTHKEY              ephemeral key; if set joins tailnet
#   GITEA_TOKEN                    pull private repo if needed
#   IMAGE_TAG                      pre-built image tag (skips local build)

set -euo pipefail

LOG=/workspace/compute-gpu.log
exec >"$LOG" 2>&1

echo "[boot] $(date -u +%FT%TZ) starting compute-gpu boot"
echo "[boot] EXECUTOR_ID=$COMPUTE_GPU_EXECUTOR_ID"
echo "[boot] LOCALITY_HOST=$COMPUTE_GPU_LOCALITY_HOST"

# ── Default announce URL (public via Cloudflare; token-gated) ─────
ANNOUNCE_URL="${RSPACE_ANNOUNCE_URL:-https://rspace.online/api/morpheus/compute/executors/announce}"

# ── Tailscale (optional) ────────────────────────────────────────────
if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
  echo "[boot] joining Tailscale"
  tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state &
  sleep 3
  tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname="$COMPUTE_GPU_EXECUTOR_ID" --accept-routes
  echo "[boot] Tailscale IP: $(tailscale ip -4)"
else
  echo "[boot] TAILSCALE_AUTHKEY unset — using public announce URL: $ANNOUNCE_URL"
fi

# ── Pull / build image ─────────────────────────────────────────────
if [[ -n "${IMAGE_TAG:-}" ]]; then
  echo "[boot] using pre-built image: rspace/compute-gpu:$IMAGE_TAG"
  docker pull "localhost:3000/rspace/compute-gpu:$IMAGE_TAG"
  IMAGE="localhost:3000/rspace/compute-gpu:$IMAGE_TAG"
else
  echo "[boot] cloning rspace-online + building locally"
  cd /workspace
  if [[ -d rspace-online ]]; then
    cd rspace-online && git pull && cd ..
  elif [[ -n "${GITEA_TOKEN:-}" ]]; then
    git clone "https://oauth2:$GITEA_TOKEN@gitea.jeffemmett.com/jeffemmett/rspace-online.git"
  else
    git clone https://github.com/Jeff-Emmett/rspace-online.git
  fi
  cd rspace-online/docker/compute-gpu
  docker build -t rspace/compute-gpu:local .
  IMAGE="rspace/compute-gpu:local"
fi

# ── Run executor ────────────────────────────────────────────────────
echo "[boot] starting compute-gpu container with announce -> $ANNOUNCE_URL"
docker rm -f compute-gpu 2>/dev/null || true
docker run -d --restart=always --name compute-gpu \
  --gpus all \
  -p 9101:9101 \
  -e COMPUTE_GPU_PORT=9101 \
  -e COMPUTE_GPU_EXECUTOR_ID="$COMPUTE_GPU_EXECUTOR_ID" \
  -e COMPUTE_GPU_HOST="${COMPUTE_GPU_HOST:-$COMPUTE_GPU_LOCALITY_HOST}" \
  -e COMPUTE_GPU_LOCALITY_HOST="$COMPUTE_GPU_LOCALITY_HOST" \
  -e COMPUTE_GPU_VRAM_MB="${COMPUTE_GPU_VRAM_MB:-24576}" \
  -e RSPACE_ANNOUNCE_URL="$ANNOUNCE_URL" \
  -e COMPUTE_EXECUTOR_TOKEN="${COMPUTE_EXECUTOR_TOKEN:?missing COMPUTE_EXECUTOR_TOKEN — refusing to start}" \
  "$IMAGE"

echo "[boot] container started — tailing announce log"
docker logs -f compute-gpu
