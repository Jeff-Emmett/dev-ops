---
id: TASK-MEDIUM.9
title: Deploy Strix Halo Mini PC as Local LLM Inference Node
status: To Do
assignee: []
created_date: '2026-04-01 02:41'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up Minisforum MS-S1 Max (AMD Strix Halo, Ryzen AI Max+ 395, 128GB unified RAM) as a dedicated local LLM inference node on the Headscale mesh. This unlocks 70B+ parameter models that cannot run on the CPU-only Netcup RS 8000. Compose files and setup script already prepared in dev-ops/strix-halo/. LiteLLM config has commented entries ready to activate.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Hardware purchased and physically set up
- [ ] #2 ROCm drivers installed, /dev/kfd accessible
- [ ] #3 Tailscale joined Headscale mesh, device visible at vpn-admin.jeffemmett.com
- [ ] #4 Ollama serving models via ROCm (ollama-strix container running)
- [ ] #5 All target models pulled: qwen2.5-coder:32b, llama3.1:70b, deepseek-r1:70b, qwen2.5:72b, plus small models
- [ ] #6 STRIX_OLLAMA_URL set in Infisical for LiteLLM project
- [ ] #7 LiteLLM config.yaml Strix Halo entries uncommented and LiteLLM restarted
- [ ] #8 End-to-end test: LiteLLM routes llama3-70b request to Strix Halo and returns response
- [ ] #9 Performance benchmarked: tokens/sec for 70b models compared to RunPod vLLM
<!-- AC:END -->
