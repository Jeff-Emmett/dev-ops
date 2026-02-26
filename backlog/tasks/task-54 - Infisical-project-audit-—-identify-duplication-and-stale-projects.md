---
id: TASK-54
title: Infisical project audit — identify duplication and stale projects
status: Done
assignee: []
created_date: '2026-02-26 00:51'
updated_date: '2026-02-26 00:51'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Audit secrets.jeffemmett.com for duplicate, stale, or redundant Infisical projects. Clarify service relationships.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Identify stale 'shared' project (no runtime consumers)
- [x] #2 Clarify immich vs rphotos are separate deployments
- [x] #3 Sync entrypoint-wrapper.sh template with deployed version
- [x] #4 Update inventory.yaml with clarifying notes
- [x] #5 Update infisical.md memory with cleanup notes
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Audit completed 2026-02-25.

Findings:
- "shared" project (25 secrets) has no runtime consumers — superseded by claude-ops. Candidate for cleanup.
- immich (personal, photos.jeffemmett.com) and rphotos (community, rphotos.online) are separate deployments, not duplicates.
- Tier 0 services (rlinks, rprofile, etc.) do not have their own Infisical projects.
- entrypoint-wrapper.sh template synced with deployed version (INFISICAL_SECRET_PATH support).

Commit: 6ee535e on dev branch.
<!-- SECTION:NOTES:END -->
