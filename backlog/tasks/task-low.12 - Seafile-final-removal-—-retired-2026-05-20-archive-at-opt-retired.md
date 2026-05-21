---
id: TASK-LOW.12
title: 'Seafile final removal — retired 2026-05-20, archive at /opt/retired'
status: To Do
assignee: []
created_date: '2026-05-19 15:48'
labels: []
dependencies: []
parent_task_id: TASK-LOW
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Seafile stack (seafile/seafile-db/seafile-memcached) cold-stopped 2026-05-20 after rFiles migrated off it (TASK-198). Held zero user data (685MB was looping seahub.log spam). Archive + rollback README at /opt/retired/seafile-2026-05-20/ on Netcup. Reclaimed ~831MB RAM / ~335MB swap. This task = the 30-day removal reminder per wiki-deprecation pattern.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 After 2026-06-19, if nothing required Seafile: docker compose down + remove /opt/apps/seafile-deploy/{db-data,seafile-data} + Traefik route (demo/files.rfiles.online),Keep /opt/retired archive one more backup cycle then delete,Fix stale cosmetic string rspace-online rcreate/data/rapps.yaml:36 ('Seafile-backed')
<!-- AC:END -->
