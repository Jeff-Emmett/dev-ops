---
id: TASK-90
title: >-
  Design holon-isolation virtualization layer (JMMJ tiers → Incus/SEV-SNP) on
  TASK-66 node
status: To Do
assignee: []
created_date: '2026-05-17 00:53'
updated_date: '2026-05-17 01:11'
labels:
  - infrastructure
  - architecture
  - jmmj
dependencies:
  - TASK-66
references:
  - dev-ops/backup-NAS/architecture.md
  - rspace-online/shared/jmmj/holon-envelope.ts
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Design (paper-only) a virtualization/isolation layer for the incoming TASK-66 local node (Minisforum MS-S1 Max, Ryzen AI Max+ 395, 128GB) that makes the JMMJ holon-envelope tiers PHYSICALLY enforced rather than code-level annotations.

Motivation: every infra incident in May 2026 (ofelia OOM, vaultwarden CF-flap, bouncer death, gitea OOM) shares one root cause — 389 containers on a single 64GB Netcup VPS with zero isolation or failover. Virtualization is the missing isolation+failover substrate. Key insight: the MS-S1 Max CPU supports AMD SEV-SNP, which is the native hardware primitive for the JMMJ `tee-bound`/`tee` tier (holon-envelope.ts already names "AMD SEV" for tee-bound transport and tee compute).

Explicit non-goal: the Netcup RS 8000 is itself a KVM guest — it will NOT be virtualized (nested-virt antipattern, negative value on a memory-starved box). This design applies ONLY to local/homelab hardware.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Recorded decision: Incus vs Proxmox VE for the TASK-66 node, with single-node-now / cluster-when-2nd-unit rationale (TASK-66 mentions clustering a 2nd unit for 256GB)
- [ ] #2 Mapping table: JMMJ SensitivityTier (public / metadata-only / encrypted / zk-attested / tee-bound) → isolation primitive (shared LXC / namespaced LXC / dedicated VM / VM+zk sidecar / SEV-SNP confidential VM)
- [ ] #3 Mapping table: JMMJ ComputeTier (js-shared / rust-sidecar / tee / zk-circuit) → runtime placement on the node
- [ ] #4 SEV-SNP feasibility on Ryzen AI Max+ 395 validated and documented (kernel/firmware/Incus support for AMD confidential VMs) — even if conclusion is 'defer'
- [ ] #5 Failover interplay defined: how holon VMs/LXCs serve as the Netcup warm-standby target (ties TASK-66 AC#9/#10) without double-counting RAM
- [ ] #6 Non-goal explicitly documented: Netcup VPS is not virtualized; rationale captured
- [ ] #7 Migration + rollback path: which Netcup services move into which holons first, and how to back out safely
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Phase 0 (this task, paper-only, no hardware needed): produce the two mapping tables + Incus/Proxmox decision + SEV-SNP feasibility note + failover interplay doc. Output lands in dev-ops/backup-NAS/architecture.md as a new "Holon isolation layer" section.
Phase 1 (gated on TASK-66 hardware): Incus base install, LXC holons for public/metadata-only tiers, Netcup-parity smoke test.
Phase 2: dedicated VMs for the encrypted tier, encrypted ZFS volumes (Morpheus storage mapping).
Phase 3: SEV-SNP confidential-VM PoC for one tee-bound holon (e.g. split-inference local-Ollama sensitive stage).
Phase 4: wire holons as Netcup warm-standby (Postgres streaming repl + CF DNS failover from TASK-66 AC#8-10).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
ARCHITECTURE SKETCH (grounded in shared/jmmj/holon-envelope.ts):

JMMJ roles: Mercury = transport (reads SensitivityTier → carrier). Morpheus = form/storage (reads sensitivity+retention → storage). Compute tier is orthogonal (picks runtime, not protection). Hypervisor scheduler becomes the infra-layer Mercury: it places/migrates holons by their envelope.

A holon = one VM/LXC with an explicit resource+trust envelope mirroring HolonEnvelope.

SensitivityTier → isolation primitive:
  public        → shared LXC, no special isolation (cheap, dense)
  metadata-only → namespaced/unprivileged LXC
  encrypted     → dedicated VM, encrypted ZFS volume (Morpheus: ciphertext + per-recipient KEM)
  zk-attested   → dedicated VM + zk-proof sidecar container
  tee-bound     → AMD SEV-SNP confidential VM: memory encrypted, never hits disk plaintext (Morpheus: enclave-only). NATIVE on Ryzen AI Max+ 395.

ComputeTier → runtime placement:
  js-shared    → shared LXC (default holon, the dense majority)
  rust-sidecar → dedicated LXC/VM for the rust-sidecar workloads (trust-engine-rs, settlement-rs, janus-knn-rs) — perf isolation
  tee          → SEV-SNP confidential VM (same box, hardware-backed)
  zk-circuit   → roadmap; likely a separate node/coprocessor, not this hardware

Incus vs Proxmox: lean Incus (LXD successor) for the single node — lighter, scriptable, does both LXC + VMs, good fit for a mostly-container workload. Switch/add Proxmox VE if/when the 2nd MS-S1 unit clusters (Proxmox HA + SEV-SNP + clustering UI mature). Decide in AC#1.

Why this is high-value HERE but negative on Netcup: virtualization is an isolation/failover substrate, not a capacity creator. On the cramped Netcup VPS it only adds an abstraction layer + overhead (and nested virt is fragile). On dedicated 128GB local hardware the holon boundaries become physically real and the box doubles as the Netcup failover target — turning a single-point-of-failure into graceful degradation.

Split-inference tie-in: the sensitive local-Ollama stages (see split_inference_v0) become a tee-bound holon in a SEV-SNP VM; only sharded/frontier-safe work crosses the boundary. The HolonEnvelope sensitivity stamp stops being advisory and becomes hardware-enforced.

Phase-0 design drafted into dev-ops/backup-NAS/architecture.md (## Holon Isolation Layer section, 2026-05-17). Covers all 7 ACs at draft level: Incus decision (single-node) w/ Proxmox-when-clustered path; both tier→primitive tables; SEV-SNP feasibility framed as Phase-1 validation w/ documented fallback; failover interplay (no RAM double-count); explicit Netcup non-virtualization non-goal; 4-step reversible migration path. ACs intentionally NOT checked — draft awaits user review; SEV-SNP validation (AC#4) is genuinely Phase-1 (needs hardware). Status left To Do.
<!-- SECTION:NOTES:END -->
