---
id: task-1
title: Configure V0.dev API access across all dev environments
status: Done
assignee: []
created_date: '2025-12-04 06:10'
updated_date: '2025-12-04 06:10'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up V0 Platform API key for programmatic access to v0.dev projects, chats, and deployments.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 V0_API_KEY exported in local bashrc
- [x] #2 ~/.v0_credentials created on Netcup with secure permissions
- [x] #3 CLAUDE.md updated with V0 section and synced
- [x] #4 v0-sdk installed globally via npm
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add V0 API key to local ~/.bashrc
2. Create ~/.v0_credentials on Netcup server
3. Update CLAUDE.md with V0 documentation
4. Install v0-sdk globally
5. Sync CLAUDE.md to Netcup
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Completed Dec 3, 2025:
- API key: v1:5AwJbit4j9rhGcAKPU4XlVWs:05vyCcJLiWRVQW7Xu4u5E03G
- 68 projects accessible via SDK
- GitHub-only git integration (no Gitea support in V0)
<!-- SECTION:NOTES:END -->
