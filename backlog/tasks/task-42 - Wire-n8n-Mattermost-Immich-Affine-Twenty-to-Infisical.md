---
id: TASK-42
title: Wire n8n, Mattermost, Immich, Affine, Twenty to Infisical
status: To Do
assignee: []
created_date: '2026-02-23 20:00'
updated_date: '2026-02-23 20:00'
labels: [infisical]
dependencies: ['TASK-39']
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate infrastructure services to Infisical using the volume-mount wrapper.

Services:
- n8n + n8n-cosmolocal (Node.js, encryption key + DB)
- Mattermost (Go/Node.js, DB + config)
- Immich (Node.js, DB + JWT)
- Affine (Node.js, DB)
- Twenty CRM x2 (Node.js, DB + auth)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [ ] 7 Infisical projects created
- [ ] All secrets migrated
- [ ] Wrapper mounted in all compose files
- [ ] All services verified
