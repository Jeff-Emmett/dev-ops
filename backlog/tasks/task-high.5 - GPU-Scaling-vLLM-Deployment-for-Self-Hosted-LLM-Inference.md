---
id: TASK-HIGH.5
title: 'GPU Scaling: vLLM Deployment for Self-Hosted LLM Inference'
status: To Do
assignee: []
created_date: '2026-04-01 00:05'
updated_date: '2026-04-01 01:49'
labels: []
dependencies: []
parent_task_id: TASK-HIGH
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Evaluate and procure GPU hardware, deploy vLLM, migrate local Ollama workloads to vLLM for higher throughput and concurrent request handling. Infrastructure prepared in dev-ops/netcup/vllm/ with docker-compose.yml and .env.example. LiteLLM config has commented vLLM model entries ready to activate.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 GPU hardware procured (Netcup vGPU, Vast.ai dedicated, or RunPod dedicated)
- [x] #2 vLLM serving at least one model behind LiteLLM
- [x] #3 LiteLLM config updated — vLLM models uncommented and active
- [ ] #4 RunPod text endpoint decommissioned (cost savings confirmed)
- [ ] #5 Performance benchmarked: vLLM vs Ollama throughput for concurrent requests
- [ ] #6 All dependent services verified (IronClaw, MCP tools, Receipt Wrangler)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## GPU Options Analysis

| Option | Cost | VRAM | Pros | Cons |
|--------|------|------|------|------|
| Netcup vGPU 7 (H200) | ~€137/mo | 7 GB | Same DC, low latency, fixed cost | Limited VRAM, availability unknown |
| Netcup vGPU 14 (H200) | ~€261/mo | 14 GB | Same DC, fits all current models | Higher cost, availability unknown |
| Vast.ai dedicated GPU | ~$0.20-0.40/hr (~$150-290/mo) | 24-80 GB | Any model size, vLLM native | External, latency, variable availability |
| RunPod dedicated pod | ~$0.30-0.50/hr (~$220-365/mo) | 24-48 GB | Already have account, vLLM templates | External, higher cost than Vast |
| Keep RunPod serverless | $50-100/mo variable | N/A | No ops, pay-per-use | No concurrency, cold starts |

## Infrastructure Prepared
- `dev-ops/netcup/vllm/docker-compose.yml` — GPU-ready compose file
- `dev-ops/netcup/vllm/.env.example` — Environment template
- `dev-ops/netcup/litellm/config.yaml` — Commented vLLM model entries ready to activate
- RunPod text endpoint (`03g5hz3hlo8gr2`) is the primary target for replacement

## RunPod vLLM Serverless (2026-03-31)
Researched and configured RunPod vLLM serverless worker integration. This replaces the existing text endpoint with vLLM-powered serverless, giving continuous batching and higher throughput at similar cost.

- LiteLLM config updated with RunPod vLLM entries (commented, ready to activate)
- Setup guide created: dev-ops/netcup/vllm/SETUP.md
- OpenAI-compatible API at: https://api.runpod.ai/v2/<ENDPOINT_ID>/openai/v1
- Needs: Create endpoint in RunPod console, add RUNPOD_VLLM_BASE_URL to Infisical litellm-proxy project
- Also kept local vLLM entries for future GPU hardware

## Deployment Complete (2026-04-01)

### What's done:
- RunPod vLLM endpoint `03g5hz3hlo8gr2` updated from openchat-3.5 to Qwen/Qwen2.5-Coder-7B-Instruct
- Endpoint renamed to 'vLLM Qwen2.5-Coder-7B'
- GPU selection: ADA_24, AMPERE_24, ADA_48_PRO, AMPERE_48, ADA_80_PRO, AMPERE_80
- RUNPOD_API_KEY + RUNPOD_VLLM_BASE_URL added to Infisical litellm-proxy project
- LiteLLM config updated with `qwen-coder-vllm` model (active, not commented)
- LiteLLM restarted on Netcup — model visible and serving
- End-to-end test PASSED: LiteLLM → RunPod vLLM → Qwen2.5-Coder response

### Known issues:
- Cold start ~2-5min (model download + GPU init). Cloudflare 524 timeout on cold requests.
- Ollama not running on Netcup — other local models (llama3, qwen-coder, etc) currently unavailable
- Worker idle timeout = 5s — good for cost, bad for response time
- Consider increasing idle timeout to 30-60s for better UX, or enable FlashBoot

### Cost impact:
- RunPod pay-per-second for GPU time only (no idle cost)
- Existing text endpoint (`03g5hz3hlo8gr2`) now serves Qwen instead of openchat
<!-- SECTION:NOTES:END -->
