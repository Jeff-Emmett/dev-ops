# compute-gpu — RunPod GPU executor for Compute-Morpheus

> **Status:** TASK-346.7 files. **Actual RunPod provisioning needs Jeff's
> RunPod API key + cost approval — not done automatically.**

Boot pattern for a RunPod pod that runs `docker/compute-gpu` and
announces itself to rspace via the rspace-internal network reachable
over Tailscale.

## Files

- `boot.sh` — runs at pod start. Builds the compute-gpu image (or pulls
  from gitea registry), exports announce env vars derived from RunPod
  metadata, runs `docker run --gpus all`.
- `Dockerfile.bootstrap` — minimal image holding boot.sh + a Tailscale
  client + docker-in-docker. Optional — only needed if the RunPod
  template can't run docker compose natively.

## Provisioning (manual — user action)

1. **Mint Tailscale auth key** in the Tailscale admin console (ephemeral,
   tagged `tag:runpod`). Add to RunPod env as `TAILSCALE_AUTHKEY`.
2. **Mint RunPod template** pointing at this directory's Dockerfile (or
   the pre-built image after first run). Required env:
   - `TAILSCALE_AUTHKEY` — from step 1
   - `RSPACE_ANNOUNCE_URL=http://rspace-netcup-tailscale-ip:3000/api/morpheus/compute/executors/announce`
   - `COMPUTE_GPU_EXECUTOR_ID=rspace.runpod.gpu-<short-pod-id>`
   - `COMPUTE_GPU_LOCALITY_HOST=runpod-<pod-id>`
   - `COMPUTE_GPU_VRAM_MB=24576` (or per-GPU)
3. **Choose GPU** in the RunPod console. L4 is recommended for proof
   (low cost, fp16/bf16 tensorcore).
4. **Start pod**. Boot script runs; pod appears in
   `/api/morpheus/compute/executors` within ~60s.
5. **Watch dispatch** at `/holonic/morpheus/log` — the rspace audit log
   shows pivots routed to the new executor.
6. **Stop pod** when done. Heartbeat staleness prune (~2min) removes
   the executor from the ComputeForge pool.

## Cost estimate

| GPU | $/hr (RunPod community) | Notes |
|---|---|---|
| L4 24GB | ~$0.30 | Recommended for proof |
| RTX 4090 24GB | ~$0.40 | Higher throughput |
| A100 40GB | ~$1.50 | LLM training class |

For the slice .11 e2e demo: ~$0.30 × 1 hour = **$0.30** sufficient.

## Why not Netcup local CUDA

Option B in the slice description: add a GPU to Netcup directly.
Defer until Netcup hardware has GPU capacity worth dedicated power /
heat budget. RunPod spot validates the heterogeneous-mesh thesis with
the correct sensitivity gating (off-prem GPUs CANNOT see `secret`
plans — that's the whole point of the gating layer).
