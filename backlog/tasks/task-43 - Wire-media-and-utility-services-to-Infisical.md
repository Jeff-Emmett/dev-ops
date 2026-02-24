---
id: TASK-43
title: Wire media & utility services to Infisical
status: To Do
assignee: []
created_date: '2026-02-23 20:00'
updated_date: '2026-02-23 20:00'
labels: [infisical]
dependencies: ['TASK-39']
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate media and utility services to Infisical.

Services:
- Jellyfin, Jellyseerr, Navidrome (minimal secrets, low priority)
- Receipt Wrangler (Python, DB + API keys)
- Open Notebook x3 (Python, API keys)
- Pocket ID (auth signing keys)
- Uptime Kuma (skip if no external secrets)
- Meeting Intelligence (Jitsi config secrets)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [ ] Projects created for services with secrets
- [ ] Uptime Kuma evaluated — skip if no external secrets
- [ ] All secrets migrated and verified
