---
id: TASK-91
title: >-
  Benchmark: OpenCode agent isolation — Docker SBX microVM vs native on ASUS
  Ascent GX10
status: To Do
assignee: []
created_date: '2026-05-21 15:00'
updated_date: '2026-05-21 16:02'
labels:
  - benchmark
  - ai-infra
  - local-ai
dependencies: []
references:
  - 'https://www.morphllm.com/docker-sandbox'
  - 'https://docs.docker.com/ai/sandboxes/agents/opencode/'
  - dev-ops/gx10/
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Compare OpenCode agent setups against a local Qwen3-VL multimodal model. **Re-scoped 2026-05-21** after discovery (see notes). Priority: max model size / capability.

## Confirmed facts
- The WSL2 dev box has **no usable NVIDIA GPU** — no local-model tier possible there.
- Docker Sandbox microVMs have **no GPU passthrough**.
- => The ASUS Ascent GX10 (GB10, 128 GB unified) is the model server in **every** config.

## What actually varies — the agent isolation layer
- **Config A:** OpenCode in a Docker SBX microVM on the no-GPU Win11/WSL2 box → GX10 LiteLLM over Tailscale.
- **Config B:** OpenCode native on the GX10 (no microVM isolation; `sbx` not on Linux yet).

## Infra (built, in `dev-ops/gx10/`)
- `litellm/` — GX10-hosted LiteLLM router (GX10 primary; RunPod demoted to burst; Netcup + cloud as fallback tiers)
- `ansible/provision-gx10.yml` — first-boot provisioning (Tailscale + Ollama + LiteLLM + UFW)
- `opencode/opencode.json` — provider config pointed at the GX10 LiteLLM
- `benchmark/harness.py` — TTFT / decode tok/s / multimodal harness

GreenBoost **dropped from scope** — no NVIDIA consumer GPU to extend, and redundant on the GX10's 128 GB unified memory.

## References
- https://www.morphllm.com/docker-sandbox
- https://docs.docker.com/ai/sandboxes/agents/opencode/
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Phase 0: sbx CLI installed on Win11 (Windows Hypervisor Platform enabled); GX10 provisioned via gx10/ansible/provision-gx10.yml (Tailscale + Ollama + LiteLLM); same Qwen3-VL model + quant pinned everywhere
- [ ] #2 Config A built: OpenCode in a Docker SBX microVM on the no-GPU consumer box reaching the GX10 LiteLLM over Tailscale; sandbox-to-GX10 reachability verified
- [ ] #3 Config B built: OpenCode running natively on the GX10 against the GX10 LiteLLM (no microVM isolation)
- [ ] #4 Inference benchmark run via gx10/benchmark/harness.py across the GX10 plus fallback tiers; results-*.{json,md} captured and committed
- [ ] #5 Agent-loop benchmark: OpenCode completes a fixed coding-task list under Config A and Config B; wall-clock and microVM boot/overhead recorded
- [ ] #6 Decision matrix produced weighted toward max model size / capability; recommendation documented in task notes with live benchmark results
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-05-21 — Discovery + re-scope. Probed the WSL2 dev box: no nvidia-smi, no CUDA stack, lspci shows no NVIDIA — the box has NO usable NVIDIA GPU (earlier 'RTX 50-series' assumption was wrong). Also confirmed the existing setup already offloads all inference over Tailscale to a tiered LiteLLM router on Netcup; OpenCode points straight at Netcup Ollama. So the GX10 is a new tier in an existing architecture, not a new tack. Decisions: GX10 runs its own LiteLLM (clients hit it directly over Tailscale); RunPod demoted to burst-only. Built the gx10/ tree in dev-ops: litellm router config + compose, ansible provisioning playbook, OpenCode provider config, benchmark harness. All files syntax-validated. Pending: GX10 hardware bring-up, then run the playbook + harness.
<!-- SECTION:NOTES:END -->
