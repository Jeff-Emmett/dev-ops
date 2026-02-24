---
id: TASK-39
title: Deploy volume-mount wrapper to /opt/infisical/ on Netcup
status: To Do
assignee: []
created_date: '2026-02-23 20:00'
updated_date: '2026-02-23 20:00'
labels: [infisical, infrastructure]
dependencies: ['TASK-34']
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deploy the shared entrypoint-wrapper.sh to Netcup so all third-party services can volume-mount it.

Steps:
1. Create /opt/infisical/ on Netcup
2. Copy entrypoint-wrapper.sh to /opt/infisical/entrypoint-wrapper.sh
3. Set permissions (chmod 755)
4. Verify it's accessible from Docker containers
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [ ] /opt/infisical/entrypoint-wrapper.sh exists on Netcup
- [ ] File is executable (755)
- [ ] Test with a simple container: volume-mount + verify detection output
