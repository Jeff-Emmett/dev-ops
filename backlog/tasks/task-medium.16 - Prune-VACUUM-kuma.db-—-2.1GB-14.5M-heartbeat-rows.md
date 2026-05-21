---
id: TASK-MEDIUM.16
title: Prune + VACUUM kuma.db — 2.1GB / 14.5M heartbeat rows
status: Done
assignee: []
created_date: '2026-05-19 15:53'
updated_date: '2026-05-19 16:32'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Uptime Kuma DB (docker volume uptime-kuma_uptime-kuma-data) is 2.1GB with 14,480,874 heartbeat rows. Retention already lowered 180->30d (2026-05-20, via kuma-alert-agent API) so Kuma's clearOldData prunes the bulk over coming cycles — but DELETE does not shrink the file and time-based prune ignores active=0. Offline pass needed to reclaim disk/RAM and purge inactive+orphan rows. Host is swap-pegged: do NOT do online bulk DELETE+VACUUM. Requires brief status.jeffemmett.com downtime (~3-5 min).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Pick low-traffic window; announce status page brief downtime,docker compose stop uptime-kuma (WAL ~4MB, clean checkpoint),Backup kuma.db before touching it,DELETE heartbeats for active=0 monitors (~351947 rows) and orphan monitor_ids (~5462 rows),DELETE heartbeats older than 30d (let Kuma do it, or batched manual),VACUUM kuma.db (2.1GB -> expect ~500-700MB),docker compose up -d uptime-kuma; verify status page + monitors report,Add recurring monthly VACUUM or document the runbook
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Done 2026-05-20 (offline maintenance, user-authorised window). kuma.db 2.1GB->658MB; 14,484,747->4,641,188 rows (-68%). Deleted: 351,947 inactive + 5,462 orphan + 9,486,150 >30d. integrity_check ok at baseline/post-delete/post-VACUUM. Backup at /opt/retired/kuma-db-backup-2026-05-20/kuma.db (delete after ~7d stable). Retention already lowered 180->30d earlier this session. Runbook committed: dev-ops/netcup/uptime-kuma/kuma-db-maintenance.md (AC8 = documented runbook). Kuma verified healthy, /dashboard 200.
<!-- SECTION:NOTES:END -->
