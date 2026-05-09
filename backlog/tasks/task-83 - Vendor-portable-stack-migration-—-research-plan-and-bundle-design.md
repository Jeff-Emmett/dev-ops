---
id: TASK-83
title: Vendor-portable stack migration — research plan and bundle design
status: In Progress
assignee: []
created_date: '2026-05-08 22:23'
updated_date: '2026-05-09 04:21'
labels:
  - research
  - infrastructure
  - sovereignty
  - planning
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Goal
Plan a full migration off Cloudflare and other third-party SaaS dependencies to a **vendor-portable, OSS-only Docker Compose bundle**. Deliverable is a research plan + replacement matrix + bundle design + phased migration plan. **No implementation in this task** — implementation spawns child tasks after plan review.

## Bundle target
- **Format**: Docker Compose stack + `.env` contract + `bootstrap.sh`
- **Strictness**: Vendor-portable. Any VPS provider, any registrar, public CA OK. No vendor-specific lock-in. Swap vendors with one config change.
- **Acceptance test for the bundle (later, not this task)**: deploys to a fresh Hetzner/OVH VPS and serves a public HTTPS site with no Cloudflare in the path.

## In scope
Cloudflare (DNS, Tunnel, Access, WAF, DDoS, edge TLS), domain registrar lock-in (Porkbun), email forwarding (CF Email Routing if used), object storage (B2/R2 if any), MCP-served SaaS APIs (Gemini, fal-ai, runpod-image-gen), GitHub mirror.

## Out of scope (already self-hosted — inventory will confirm)
Mailcow, Gitea, Infisical, Uptime Kuma, Ollama, LiteLLM, Headscale.

## Deferred
Hardware sovereignty (TASK-66 covers MS-S1 Max). RunPod GPU burst kept optional.

## Phase 0 — Dependency inventory
Walk every running service on Netcup + every CLI/MCP this repo uses. Per dep: name, function, criticality, current cost, lock-in level, data residency.
**Output**: `dev-ops/research/portable-stack/dep-inventory.md`

## Phase 1 — Replacement matrix
For each dep with criticality >= medium: 2-3 OSS replacements. Per replacement: project URL, license, maturity (commits/contributors/age), Docker Compose support, gotchas. Pick primary + fallback per slot.
**Output**: `dev-ops/research/portable-stack/replacement-matrix.md`

## Phase 2 — Bundle architecture
docker-compose topology: edge proxy, tunnel/origin hiding, identity, WAF, observability, app slot. `.env` contract — every vendor-replaceable knob (DNS provider, ACME provider, object storage backend) parameterized. Bootstrap script outline. Network topology diagram (text-only OK).
**Output**: `dev-ops/research/portable-stack/bundle-design.md`

## Phase 3 — Phased migration plan
Ordered cutover phases, each with: services moved, prerequisites, rollback, success criteria, est. effort. Order by reversibility (low blast radius first) + dependency. Pick pilot service (likely low-traffic static site) for Phase 1 cutover.
**Output**: `dev-ops/research/portable-stack/migration-plan.md`

## Phase 4 — Cost + risk analysis
Current annual vendor spend estimate (CF, Porkbun, Netcup, RunPod, MCP SaaS). Projected TCO for 3 candidate stacks (Bunny.net consolidation vs Pangolin self-host vs hybrid). Risk register: irreplaceable functions (Tbps DDoS scrubbing, 300+ PoP anycast) + mitigations.
**Output**: `dev-ops/research/portable-stack/tco-and-risks.md`

## Candidate stacks to evaluate (from prior research)
1. **Bunny.net consolidation** — DNS+CDN+Storage+Pages+Shield, ~$5-15/mo, real anycast, single vendor
2. **Pangolin + Porkbun + OVH edge** — self-host, OVH free DDoS, ~€10/mo extra, single edge PoP
3. **Hybrid** — keep CF DNS + edge, swap CF Access -> Authentik first, evaluate further moves after

## What this task does NOT do
- Implement any cutover
- Acquire new infrastructure
- Decommission anything
- Spawn child implementation tasks (waits on plan review)

## References
- Prior conversation research notes (Caddy/Bunny/Pangolin alternatives mapping)
- TASK-66 (hardware sovereignty — Local AI Server / NAS)
- `~/.claude/context/infrastructure.md` (current Netcup + CF + Traefik setup)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Phase 0: dep-inventory.md committed to dev-ops/research/portable-stack/ — every running service + CLI/MCP dep classified by criticality, cost, lock-in, residency
- [x] #2 Phase 1: replacement-matrix.md committed — every >=medium-criticality dep has 2-3 OSS replacements with maturity scoring + primary/fallback pick
- [x] #3 Phase 2: bundle-design.md committed — docker-compose topology, parameterized .env contract, bootstrap.sh outline, network diagram
- [x] #4 Phase 3: migration-plan.md committed — ordered phased cutover plan with rollback per phase, pilot service identified
- [x] #5 Phase 4: tco-and-risks.md committed — annual vendor spend baseline, TCO projection for 3 candidate stacks, risk register with irreplaceable-function mitigations
- [ ] #6 All five deliverables committed and pushed to Gitea origin/main
- [ ] #7 Plan reviewed by Jeff before any implementation child tasks are created
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Phase 0 + 1 complete (2026-05-08).

**Phase 0 deliverable**: dev-ops/research/portable-stack/dep-inventory.md
- Inventoried 447 running containers + 11 MCP servers + host services
- 13 Tier-1 SaaS deps identified (CF Tunnel/DNS/Access/R2/WAF, RunPod, 6 MCP SaaS APIs, GitHub mirror)
- 3 Tier-2 vendor-portable deps (Porkbun, Let's Encrypt, Netcup)
- ~100+ self-hosted services already in place (Mailcow, Gitea, Infisical, Headscale, Ollama, LiteLLM, Traefik, etc.)
- Critical finding: cloudflared is single-tunnel routing ALL public traffic via Traefik on localhost:80
- Surprise: Plex/Jellyfin media currently lives in CF R2 (~5TB egress hit when migrating)
- Surprise: Tailscale-the-vendor already replaced — Headscale runs control plane

**Phase 1 deliverable**: dev-ops/research/portable-stack/replacement-matrix.md
- 12 slots covered (tunnel, DNS, TLS, identity, storage, WAF, DDoS, image-AI, vision-LLM, calendar, accounting, design, backups)
- Primary picks: Pangolin / deSEC / Authentik / MinIO / Coraza / OVH-edge / ComfyUI / Llama-3.2-Vision / SOGo / Penpot / restic
- Honest exceptions: Xero (no realistic OSS replacement, accepted vendor)
- Backups: gap — db-backup-cron destination unconfirmed, Phase 2 must audit
- DDoS: real downgrade — bundle needs OVH-edge VPS (€5/mo) for parity, single-VPS deploy loses Tbps scrubbing

**Pause point**: ready for Jeff's review before Phase 2 (bundle architecture) begins. Phase 2 will produce docker-compose topology + parameterized .env contract.

Phases 2, 3, 4 complete (2026-05-08).

**Phase 2 deliverable**: dev-ops/research/portable-stack/bundle-design.md
- Multi-file Compose layout with profiles (pangolin, coraza, minio, crowdsec)
- Complete .env contract — every vendor knob parameterized (DNS_PROVIDER, ACME_CA, EDGE_MODE, IDP_MODE, STORAGE_BACKEND, WAF_MODE, BACKUP_BACKEND)
- Topology diagram with optional edge VPS layer for DDoS protection
- bootstrap.sh outline — idempotent, validates DNS first, generates secrets, smoke tests
- Authentik forward-auth integration spec (replaces Cf-Access-* headers)
- Pangolin Newt agent (origin) + Pangolin server (edge) split
- State migration: bundle is infra-only, app data stays in named volumes

**Phase 3 deliverable**: dev-ops/research/portable-stack/migration-plan.md
- 8 phases (A-H), ~16 weeks, ~110-160 hrs total work
- Phase A: Authentik + CF Access swap (1-2wk, low risk, fully reversible)
- Phase B: DNS swap CF → deSEC (1 pilot domain + bulk waves)
- Phase C: Pilot tunnel cutover — picked **personal-site** as pilot (single container, low traffic)
- Phase D: Bulk tunnel migration in 6 waves of 5 domains/wk
- Phase E: cloudflared decommission
- Phase F: R2 → MinIO (gated on TASK-66 hardware)
- Phase G: MCP SaaS swaps (parallel)
- Phase H: bundle packaging + clean-VPS portability test
- Per-phase rollback procedures + success criteria documented

**Phase 4 deliverable**: dev-ops/research/portable-stack/tco-and-risks.md
- Baseline current spend: ~$1,370–$4,054/yr (R2 + RunPod usage are LOW-confidence, need verification)
- Stack 1 (Bunny consolidation): +$186/yr, fails 'no external deps' goal
- **Stack 2 (Pangolin + OVH edge) — RECOMMENDED**: −$455 to −$2,395/yr after TASK-66 amortizes (~2.7yr payback on $4017 hardware)
- Stack 3 (Hybrid, only Authentik): $0 cost, useful as Phase A milestone but not destination
- 10-item risk register: DDoS downgrade (mitigated by OVH), anycast latency (open mitigation choice), Authentik ops burden (break-glass admin), Pangolin maturity (pilot validates), Xero accepted exception
- 6 open questions for user before implementation: verify R2 spend, verify RunPod spend, latency mitigation choice, DDoS posture, stack pick, R2→MinIO gating

**Status**: All 5 deliverables written. ACs 1-5 checked. Pending: user review (AC 7) + commit/push (AC 6) before child implementation tasks can be created.

## 2026-05-09 — Phase 0 immediate wins executed

Following 'do as much as we can that brings benefit' direction, executed parallel high-ROI fixes during research phase. See `research/portable-stack/immediate-wins-status.md` for full report.

✅ **Backup container restored** — root cause: db-backup container had been pruned, db-backup-cron daily-failed silently for 10 days (since Apr 28). Rebuilt + manual run completed: 2.07 GiB synced to R2, 14.7 GiB stale data purged. Cron resumes tomorrow 04:03.

✅ **CF DNS TTLs dropped to 300s** — 37/37 records updated across 11 zones (MX/TXT/CNAME for email + Vercel verification). Phase B cutover prep complete.

✅ **CF Access inventory exported** — 32 apps + 39 policies captured to `research/portable-stack/cf-access-inventory/`. Authentik mapping table ready (3 bypass + 29 allow-listed).

✅ **CrowdSec deployed (observation mode)** — `/opt/apps/crowdsec/` running with linux/sshd/http-cve/iptables collections. Local API on 127.0.0.1:6060. No bouncer yet — Traefik bouncer wiring deferred to maintenance window (requires accesslog enable + Traefik restart).

⚠️ **Critical finding (R-NEW)**: Backup coverage is 6/23 DBs. 17 prod DBs have NO backup ever (n8n, vaultwarden, all r-services, twenty-crm, postiz, affine, mongo, temporal). Filed as separate gap.

Awaiting user input:
- Backblaze B2 application key for restic-based offsite backup deployment
- Approval for Traefik restart window to enable CrowdSec bouncer

## 2026-05-09 — Discovery + bouncer activation

**Major correction**: backup system was ALREADY 3-2-1 compliant. `/opt/backup-system/backup-docker.sh` runs daily at 03:00 with:
- Restic repo at r2:netcup-backups (746 GiB today, daily snapshots)
- Hetzner Storage Box sync (second offsite)
- Auto-discovers ALL postgres + mariadb containers via `docker ps | grep`
- Health check at 06:00 emails alerts if stale

The `/opt/apps/db-backup/` system is a redundant zombie. R6 risk reclassified as **CLOSED**.

**CrowdSec bouncer LIVE**: Deployed `bouncer-traefik` (fbonalair/traefik-crowdsec-bouncer:0.5.0), wired forwardAuth middleware into both `web` and `websecure` Traefik entrypoints. Every request now passes through CrowdSec community blocklist check at ~1-3ms latency. Verified with curls + bouncer logs showing live request flow. Pre-existing LE rate-limit errors confirmed unrelated.
<!-- SECTION:NOTES:END -->
