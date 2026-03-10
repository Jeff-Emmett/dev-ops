---
id: TASK-59
title: Consolidate Postiz Temporal and Elasticsearch infrastructure
status: Done
assignee:
  - '@claude'
created_date: '2026-03-10 21:23'
labels:
  - infrastructure
  - postiz
  - optimization
dependencies: []
references:
  - netcup/postiz/shared-temporal-docker-compose.yml
  - netcup/postiz/main-docker-compose.prod.yaml
  - netcup/postiz/cc-docker-compose.yml
  - netcup/postiz/p2pf-docker-compose.yml
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Each of 5 Postiz instances ran its own embedded Temporal server + Postgres + Elasticsearch stack. This duplicated ~5 GB of RAM on identical infrastructure.

Consolidation: shared Postgres (multi-database) + shared Elasticsearch + shared Temporal UI, with each Postiz keeping its own Temporal server for namespace isolation. BCRG and VOTC shut down.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Shared Temporal infra deployed (temporal-shared-postgres, temporal-shared-elasticsearch, temporal-shared-ui)
- [ ] #2 Main Postiz Temporal migrated to shared infra
- [ ] #3 CC Postiz Temporal migrated to shared infra
- [ ] #4 P2PF Postiz Temporal migrated to shared infra
- [ ] #5 BCRG Postiz shut down
- [ ] #6 VOTC Postiz shut down
- [ ] #7 Legacy standalone Temporal stack removed
- [ ] #8 Repo compose files synced with server
- [ ] #9 RAM reduced from ~5 GB to ~1.5 GB (12 containers → 6)
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Consolidated Postiz Temporal infrastructure from 12 containers (~5 GB RAM) to 6 containers (~1.5 GB RAM). Created shared-temporal stack at /opt/postiz/shared-temporal/ with shared Postgres (separate DBs per instance via DBNAME/VISIBILITY_DBNAME), shared Elasticsearch, and Temporal UI. Each active Postiz instance (main, cc, p2pf) keeps its own Temporal server container pointing at shared infra for namespace isolation. BCRG and VOTC shut down. Legacy standalone Temporal removed. All repo compose files match server.
<!-- SECTION:FINAL_SUMMARY:END -->
