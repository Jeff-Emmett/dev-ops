# funion-qwen-coder — RunPod serverless deployment guide

> **Status:** Drafted but **NOT deployed**. Pulls the trigger on a paid
> RunPod serverless endpoint; deployment is a manual step Jeff runs
> when the funion stack needs the heavy model tier.

## What this is

The third tier of the funion model stack:

| Tier | Hosted on | Model | Lat (tok/s) | Idle cost |
|---|---|---|---|---|
| 1 | Netcup CPU | Phi-3-mini Q4 | ~1.5 | $0 |
| 2 | Netcup CPU | Llama-3.1-8B Q4 | ~0.6 | $0 |
| **3 (this)** | **RunPod 4090 / A40** | **Qwen2.5-Coder-32B Q4** or **Llama-3.1-70B Q4** | **~30+** | **$0** (serverless) |

Auto-scales to zero when idle, ~$0.34-0.40/hr while active, ~30s cold
start.

## Deployment runbook

### 1. RunPod account + API key

You already have one (per `~/.claude/CLAUDE.md`). API key in Infisical
under `claude-ops-shared` or `ai-services-shared`. Confirm with:

```sh
ssh netcup-full 'set -a; . /opt/infisical/claude-ops.env; set +a; \
  infisical secrets --domain=https://secrets.jeffemmett.com \
  --projectId=<id> --env=prod 2>/dev/null | grep -i RUNPOD'
```

Or via the RunPod web console: <https://www.runpod.io/console/user/settings>

### 2. Pick a model + GGUF / safetensors

For a code-focused stack:

| Model | Repo | VRAM (Q4) | RunPod SKU |
|---|---|---|---|
| **Qwen2.5-Coder-32B-Instruct** | `Qwen/Qwen2.5-Coder-32B-Instruct` (HF) | ~22 GB | RTX 4090 24GB ($0.34/hr) tight; A40 48GB ($0.40/hr) comfortable |
| Llama-3.1-70B-Instruct Q4 | `meta-llama/Llama-3.1-70B-Instruct` | ~42 GB | A40 48GB tight; A100-80GB ($1.50/hr) comfortable |
| Llama-3.1-8B (existing tier 2 in GPU mode) | `meta-llama/Llama-3.1-8B-Instruct` | ~6 GB | RTX 4090 |

Recommended starting point: **Qwen2.5-Coder-32B-Instruct on A40**
serverless. Best price/performance for coding workloads.

### 3. Create RunPod serverless endpoint

Two options:

**Option A — RunPod's official vLLM template (simpler).**

1. Go to <https://www.runpod.io/console/serverless/user/templates>
2. Pick "vLLM" template
3. Set environment:
   ```
   MODEL_NAME=Qwen/Qwen2.5-Coder-32B-Instruct
   MAX_MODEL_LEN=32768
   GPU_MEMORY_UTILIZATION=0.95
   QUANTIZATION=awq            # or bitsandbytes for Q4
   DTYPE=auto
   ```
4. Pick GPU: A40 48GB (or RTX 4090 24GB if using bitsandbytes Q4)
5. Set min workers = 0, max workers = 2, idle timeout = 60s
6. Note the endpoint ID and the URL: `https://api.runpod.ai/v2/<ENDPOINT_ID>/openai/v1`

**Option B — custom Docker image.**

Build our own image at `funion-sidecar-gpu:vllm` that wraps vLLM and
adds a /v1/chat/completions auth layer matching the funion-sidecar
pattern. More work; only needed if Option A doesn't satisfy our
auth/observability needs.

### 4. LiteLLM model entry

Add to `/opt/apps/litellm/config.yaml` and `dev-ops/netcup/litellm/config.yaml`:

```yaml
  # ===========================================================
  # TIER 3 — funion sidecar (Qwen2.5-Coder-32B, RunPod serverless)
  # GPU-accelerated. Auto-scales to zero; ~$0.40/hr while warm.
  # ===========================================================
  - model_name: funion-qwen-coder-32b
    litellm_params:
      model: openai/Qwen/Qwen2.5-Coder-32B-Instruct
      api_base: https://api.runpod.ai/v2/<ENDPOINT_ID>/openai/v1
      api_key: os.environ/RUNPOD_API_KEY
      timeout: 600
```

`RUNPOD_API_KEY` already exists in the LiteLLM env (used by other
RunPod-backed models). Reuse.

### 5. Update funion-mcp model catalogue

In `zknet-labs-src/src/core/funion-mcp/cmd/funion-mcp/main.go` uncomment
the third entry in `modelCatalogue`:

```go
{"funion-qwen-coder-32b", "Qwen2.5-Coder-32B-Instruct (Q4 awq)",
 "fast-gpu (~30 tok/s)", true, "RunPod serverless A40"},
```

Rebuild the binary, copy to `~/bin/funion-mcp`, restart any open
Claude Code sessions.

### 6. Smoke

```sh
# direct LiteLLM:
ssh netcup-full 'docker exec litellm sh -c "..."'   # see M2 task for the full script

# via funion-mcp (warm session):
echo '{"jsonrpc":"2.0",...}' | ~/bin/funion-mcp
```

Expected: ~30s cold start (RunPod spinup) for the first request, then
sub-second response on repeat queries while the worker stays warm.

## Cost guards

- Min workers = 0 — never charged while idle.
- Max workers = 2 — caps spend even if a runaway client retries.
- LiteLLM model `max_budget` setting already in place at `$50/30d`;
  RunPod calls land in the same budget.

## What this guide does NOT cover

- Custom auth in front of the RunPod endpoint. RunPod's serverless
  doesn't easily let you put bearer-token auth on the public URL — the
  `RUNPOD_API_KEY` is the auth. Do not expose the endpoint URL outside
  LiteLLM.
- Per-user rate limits. Use LiteLLM virtual keys (already done for
  Phi-3 and Llama-3.1-8B) to scope which keys can call funion-qwen-
  coder-32b. Issuing a new vkey for a per-user funion-tier-3 quota is
  a separate task.
- Cold-start optimisation. RunPod's "FlashBoot" reduces cold start
  from ~2 min to ~30s; enable in the template settings.

## Tracking

When this lands, mark `funion-rollout` TASK-006 (M5) as Done. Update:
- `dev-ops/netcup/litellm/config.yaml` (committed)
- `zknet-labs-src/src/core/funion-mcp/cmd/funion-mcp/main.go`
  (modelCatalogue) and rebuild
- `dev-ops/runpod/funion-qwen-coder/README.md` with the actual ENDPOINT_ID
- `/opt/apps/funion-sidecar/README.md` on Netcup with the new tier-3 row
