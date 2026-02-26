---
id: TASK-55
title: Remove stale 'shared' Infisical project
status: To Do
assignee: []
created_date: '2026-02-26 01:17'
updated_date: '2026-02-26 01:17'
labels: []
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 'Shared Infrastructure' Infisical project (slug: shared, 25 secrets) has no runtime consumers. claude-ops replaced it. Delete via Infisical API from Netcup.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Confirm no services reference slug 'shared' at runtime (verified 2026-02-25)
- [ ] #2 Delete project via Infisical API on Netcup
- [ ] #3 Remove from infisical.md project table
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Commands to run on Netcup:
  source /opt/infisical/claude-ops.env
  TOKEN=$(curl -sf -X POST http://infisical:8080/api/v1/auth/universal-auth/login ...)
  curl -sf -X DELETE http://infisical:8080/api/v2/workspace/<ID> -H "Authorization: Bearer $TOKEN"
<!-- SECTION:NOTES:END -->
