---
id: TASK-MEDIUM.8
title: Build backup NAS + warm standby failover server
status: To Do
assignee: []
created_date: '2026-03-25 18:22'
due_date: '2026-04-08'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Multi-location redundancy system for Netcup RS 8000. Local mini-server + NAS array providing: (1) Large NAS storage replacing Hetzner Storage Box, (2) Warm standby Docker containers ready to promote on Netcup failure, (3) Local Jellyfin for LAN playback, (4) Third backup copy for 3-2-1 strategy (Netcup + R2 + local), (5) Future dAppNode/ETH staking (TASK-60). Hardware ~$1,100-1,500 one-time, saves ~$35/mo vs current Hetzner costs, breakeven ~30-36 months. Architecture, BOM, and 6-step setup scripts already drafted in dev-ops/backup-NAS/.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Hardware sourced and assembled
- [ ] #2 Base OS installed with Docker and Tailscale (01-base-install.sh)
- [ ] #3 RAID storage configured and mounted (02-storage-setup.sh)
- [ ] #4 Restic backup target configured with PostgreSQL streaming replication (03-backup-target.sh)
- [ ] #5 Jellyfin + arr stack deployed for local media (04-media-server.sh)
- [ ] #6 Critical services running as warm standby (05-warm-standby.sh)
- [ ] #7 Cloudflare health checks and failover routing configured (06-failover.sh)
- [ ] #8 Manual failback procedure tested
<!-- AC:END -->
