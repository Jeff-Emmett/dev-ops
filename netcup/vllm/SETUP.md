# vLLM Integration

Two deployment paths — RunPod serverless (now) and local GPU (future).

## Option A: RunPod vLLM Serverless (Recommended)

Uses RunPod's managed vLLM worker with GPU on-demand. Pay-per-second, no idle cost.

### 1. Create Endpoint

1. Go to [RunPod Console → Serverless → Quick Deploy → vLLM](https://console.runpod.io/serverless)
2. Select latest vLLM worker version
3. Set model: `Qwen/Qwen2.5-Coder-7B-Instruct` (or any HF model)
4. Advanced settings:
   - **Max Model Length:** 4096
   - **GPU Memory Utilization:** 0.95
   - **Max Workers:** 2
   - **Idle Timeout:** 15s (or 0 for no idle cost)
   - **FlashBoot:** Enable (reduces cold start from ~60s to ~10s, +10% cost)
5. Click "Create Endpoint" → note the **Endpoint ID**

### 2. Add Secrets to Infisical

In `litellm-proxy` project, add:
```
RUNPOD_VLLM_BASE_URL=https://api.runpod.ai/v2/<ENDPOINT_ID>/openai/v1
```

`RUNPOD_API_KEY` should already be available (check `claude-context` project).

### 3. Activate in LiteLLM Config

Uncomment the RunPod vLLM section in `litellm/config.yaml`:
```yaml
  - model_name: qwen-coder-vllm
    litellm_params:
      model: openai/Qwen/Qwen2.5-Coder-7B-Instruct
      api_base: os.environ/RUNPOD_VLLM_BASE_URL
      api_key: os.environ/RUNPOD_API_KEY
      timeout: 120
```

### 4. Restart LiteLLM

```bash
ssh netcup 'cd /opt/apps/litellm && docker compose up -d --force-recreate'
```

### 5. Test

```bash
curl -X POST https://llm.jeffemmett.com/v1/chat/completions \
  -H "Authorization: Bearer <LITELLM_MASTER_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen-coder-vllm", "messages": [{"role": "user", "content": "Hello"}]}'
```

### Cost Comparison

| Scenario | RunPod Serverless (current) | RunPod vLLM Serverless |
|----------|----------------------------|------------------------|
| Cold start | Variable | ~10s with FlashBoot |
| Concurrent requests | 1 at a time | Continuous batching (vLLM) |
| Throughput | Basic | 2-4x via PagedAttention |
| Pricing | Per-request | Per-second GPU time |

## Option B: Local vLLM (When GPU Available)

Use `docker-compose.yml` in this directory. Requires NVIDIA GPU with CUDA drivers.

1. Uncomment GPU `deploy` section in docker-compose.yml
2. Copy `.env.example` to `.env` and configure
3. `docker compose up -d`
4. Uncomment "vLLM Local" section in `litellm/config.yaml`

## Replacing Existing RunPod Text Endpoint

Current text endpoint: `03g5hz3hlo8gr2`

Once vLLM serverless is verified:
1. Update consumers to use `qwen-coder-vllm` model name via LiteLLM
2. Add vLLM models to `cheap-code` load-balanced group
3. Decommission old text endpoint in RunPod console
