---
id: TASK-39
title: Deploy volume-mount wrapper to /opt/infisical/ on Netcup
status: Done
assignee: ['@claude']
created_date: '2026-02-23 20:00'
updated_date: '2026-02-24 01:40'
labels: [infisical, infrastructure]
dependencies: ['TASK-34']
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deploy the shared entrypoint-wrapper.sh to Netcup so all third-party services can volume-mount it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [x] /opt/infisical/entrypoint-wrapper.sh exists on Netcup
- [x] File is executable (755)
- [x] Deployed via deploy-pkmn.sh script

## Notes

Deployed as part of PKMN migration (task-36).
