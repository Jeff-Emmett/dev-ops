---
id: TASK-66
title: Build Local AI Server + NAS + Failover (Minisforum MS-S1 Max)
status: To Do
assignee: []
created_date: '2026-04-03 19:00'
labels:
  - infrastructure
  - ai
  - nas
  - hardware
milestone: May 2026
dependencies:
  - TASK-MEDIUM.9
references:
  - dev-ops/backup-NAS/BOM.html
  - dev-ops/backup-NAS/hardware-comparison.md
  - dev-ops/backup-NAS/architecture.md
  - dev-ops/backup-NAS/setup/
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Purchase and deploy Minisforum MS-S1 Max (Ryzen AI Max+ 395, 128GB unified RAM) as local AI inference server, NAS, media server, and warm standby failover for Netcup.

## Hardware BOM (~$4,017)
- Minisforum MS-S1 Max 128GB/2TB ($2,959) — [Amazon](https://www.amazon.com/MINISFORUM-AMD-Ryzen-Max-395/dp/B0G2VJR4JD)
- TerraMaster D4-320 4-bay NAS enclosure ($152)
- 2x WD Ultrastar HC560 20TB Renewed ($656)
- CyberPower CP1500AVRLCD3 UPS ($220)
- Cat6a cable + misc ($30)

## What This Enables
- Local 70B+ LLM inference (Ollama + ROCm → LiteLLM)
- 20TB NAS replacing Hetzner Storage Box (~$55/mo savings)
- Local Jellyfin movie server (direct play, no buffering)
- Warm standby for critical Netcup services (Traefik, rSpace, EncryptID, rInbox)
- 3-2-1 backup (third location: Netcup + R2 + local)
- PostgreSQL streaming replication
- Automatic Cloudflare DNS failover
- Future: add discrete GPU via PCIe x16, cluster second unit for 256GB

## Key Notes
- RAM is SOLDERED (LPDDR5x) — not upgradeable — must buy 128GB
- Dual 10GbE for NAS throughput, USB4 V2 (80Gbps) for clustering
- Watch price — historical low was $2,299, currently $2,959 due to RAM crisis
- Setup scripts ready in dev-ops/backup-NAS/setup/
- LiteLLM config has commented Strix Halo entries ready to activate

## Reference Files
- `dev-ops/backup-NAS/BOM.html` — Full BOM with product images + purchase links
- `dev-ops/backup-NAS/hardware-comparison.md` — Device comparison + LLM benchmarks
- `dev-ops/backup-NAS/architecture.md` — Network topology + failover design
- `dev-ops/backup-NAS/setup/` — Step-by-step setup scripts (phases 1-6)

## Implementation Phases
1. Hardware purchase + assembly + Ubuntu Server install
2. ROCm + Ollama + local AI stack → connect to LiteLLM
3. NAS setup + media migration from Hetzner
4. Backup consolidation (Restic target + KeePass 3-2-1)
5. Warm standby containers + PostgreSQL streaming replication
6. Cloudflare health checks + automatic DNS failover
7. Cancel Hetzner, evaluate dAppNode on same hardware
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Hardware purchased and physically assembled
- [ ] #2 Ubuntu Server 24.04 installed, Docker + Tailscale joined Headscale mesh
- [ ] #3 ROCm drivers installed, Ollama serving models via GPU (/dev/kfd accessible)
- [ ] #4 Target models pulled: qwen2.5-coder:32b, llama3.1:70b, deepseek-r1:70b, qwen3-30b-a3b
- [ ] #5 LiteLLM Strix Halo entries activated, end-to-end inference test passing
- [ ] #6 NAS RAID1 configured, media migrated from Hetzner, Jellyfin serving locally
- [ ] #7 Restic backup target configured, KeePass 3-2-1 verified (TASK-28)
- [ ] #8 PostgreSQL streaming replication running for rSpace, EncryptID, rInbox
- [ ] #9 Warm standby containers deployed (Traefik, rSpace, EncryptID, rInbox)
- [ ] #10 Cloudflare health check + DNS failover tested and operational
- [ ] #11 Hetzner Storage Box cancelled or downgraded
- [ ] #12 UPS monitoring (NUT) configured with clean auto-shutdown
<!-- AC:END -->
