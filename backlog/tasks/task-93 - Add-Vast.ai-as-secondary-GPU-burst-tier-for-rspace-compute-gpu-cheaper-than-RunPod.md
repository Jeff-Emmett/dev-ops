---
id: TASK-93
title: >-
  Add Vast.ai as secondary GPU burst tier for rspace compute-gpu (cheaper than
  RunPod)
status: To Do
assignee: []
created_date: '2026-06-20 11:44'
labels:
  - rspace-online
  - gpu
  - infra
  - vast.ai
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Vast.ai undercuts RunPod ~20-40% on $/hr at the A5000/RTX 4090/L4/A100 class the rspace Compute-Morpheus executor uses. Verified read-only: cheapest reliable RTX 4090 offer = $0.3214/hr vs RunPod community $0.34.

Scaffold shipped in `dev-ops/vastai/compute-gpu/` (mirror of `dev-ops/runpod/compute-gpu/`): up.sh / boot.sh / down.sh / status.sh / README.md. Scripting-only — ZERO rspace-online code change:
- Executor image + server.py + announce.py + cost-ranked dispatch (compute-forge.ts) are already provider-agnostic.
- server.py:52 honours COMPUTE_GPU_PUBLIC_ENDPOINT; boot.sh sets it to the instance tailnet IP (Vast has no RunPod-style proxy URL).
- Dispatch cost-ranks every announced executor by dollarsPerOp, so a cheaper Vast executor auto-wins routing — no router priority to set.

Creds/prereqs already in place: ~/.secrets/private/vastai_api_key (tracked in secrets-inventory.yaml + runbook-external-api-key.md), vastai CLI v0.5.0, UFW VastAI tunnel rule. Only runtime need: ephemeral TAILSCALE_AUTHKEY tagged tag:vastai.

Remaining = live validation (costs money): mint tag:vastai authkey, run ./up.sh, confirm announce + a dispatched plan executes, then ./down.sh. Confirm userspace Tailscale isn't blocked on the chosen offer. Relates to TASK-88 Phase-2 Vast.ai expectation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Mint ephemeral Tailscale authkey tagged tag:vastai
- [ ] #2 ./up.sh provisions a Vast RTX 4090 instance and it announces to the rspace ComputeForge pool
- [ ] #3 A dispatched ComputePlan executes on the Vast executor (verify in /holonic/morpheus/log)
- [ ] #4 ./down.sh drains (mark-dead) and destroys the instance cleanly; --all clears stragglers
- [ ] #5 Confirm userspace Tailscale works on the chosen offer class (or document fallback)
- [ ] #6 README cost table reflects live observed $/hr
<!-- AC:END -->
