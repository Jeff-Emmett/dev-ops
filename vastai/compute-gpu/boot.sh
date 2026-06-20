#!/usr/bin/env bash
# Vast.ai on-start wrapper for the rspace compute-gpu executor.
#
# Unlike RunPod (which exposes a stable https://<pod>-<port>.proxy.runpod.net
# URL), Vast.ai assigns an unpredictable public host:port per instance — so we
# route rspace's executor callback over Tailscale instead and advertise the
# tailnet endpoint via COMPUTE_GPU_PUBLIC_ENDPOINT (server.py honours it,
# see docker/compute-gpu/server.py:52).
#
# This runs INSIDE the pre-baked executor image (ghcr.io/.../rspace-compute-gpu),
# which is WORKDIR /app + `python3 server.py`. We just add Tailscale, compute
# the endpoint, then exec the server. NO docker-in-docker.
#
# Required env (passed via `vastai create instance --env`):
#   COMPUTE_EXECUTOR_TOKEN     shared secret matching rspace/prod
#   COMPUTE_GPU_EXECUTOR_ID    rspace.vastai.gpu-<unique>
#   COMPUTE_GPU_LOCALITY_HOST  vastai-<instance>
#   COMPUTE_GPU_VRAM_MB        per-GPU VRAM in MB
#   TAILSCALE_AUTHKEY          ephemeral key, tag:vastai — REQUIRED on Vast
# Optional:
#   RSPACE_ANNOUNCE_URL        default https://rspace.online/...
#   COMPUTE_GPU_PORT           default 9101

set -euo pipefail

LOG=/var/log/compute-gpu-boot.log
exec >"$LOG" 2>&1
echo "[boot] $(date -u +%FT%TZ) starting vastai compute-gpu boot"
echo "[boot] EXECUTOR_ID=${COMPUTE_GPU_EXECUTOR_ID:-unset}"

PORT="${COMPUTE_GPU_PORT:-9101}"

# ── Vast has no provider proxy URL: Tailscale is mandatory for callback ──
: "${TAILSCALE_AUTHKEY:?Vast executor requires TAILSCALE_AUTHKEY (rspace must call back over the tailnet)}"

# ── Deps not in the CUDA base image (curl + ip) ─────────────────────
apt-get update -qq
apt-get install -y -qq --no-install-recommends curl iproute2 >/dev/null

# ── Join Tailscale (userspace netstack — no /dev/net/tun needed) ─────
echo "[boot] installing + joining Tailscale"
curl -fsSL https://tailscale.com/install.sh | sh
mkdir -p /var/lib/tailscale
tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state &
sleep 3
TS_HOSTNAME="${COMPUTE_GPU_EXECUTOR_ID//./-}"
tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname="$TS_HOSTNAME" --accept-routes
TS_IP=$(tailscale ip -4 | head -1)
echo "[boot] tailnet IP: $TS_IP  hostname: $TS_HOSTNAME"

# ── Advertise the tailnet endpoint rspace will call back on ─────────
export COMPUTE_GPU_PUBLIC_ENDPOINT="http://${TS_IP}:${PORT}/execute"
export COMPUTE_GPU_HOST="0.0.0.0"
echo "[boot] COMPUTE_GPU_PUBLIC_ENDPOINT=$COMPUTE_GPU_PUBLIC_ENDPOINT"

# ── Run the executor (binds 0.0.0.0:$PORT, announces to rspace) ─────
cd /app
echo "[boot] exec python3 server.py"
exec python3 server.py
