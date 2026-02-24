---
id: TASK-37
title: Wire payment-infra to Infisical (30+ secrets)
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
Migrate payment-infra secrets to Infisical. Most complex service: 8 sub-services share ~30 secrets including blockchain keys, payment processor credentials, and DB passwords.

Steps:
1. Create Infisical project `payment-infra`
2. Categorize secrets by sub-service (may need secret paths: /api, /worker, /gateway, etc.)
3. Push all secrets to Infisical
4. Add Node.js entrypoint to each service's Dockerfile
5. Update docker-compose.yml
6. Deploy and verify all 8 services
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [ ] Infisical project `payment-infra` created
- [ ] All 30+ secrets migrated (organized by path if needed)
- [ ] All 8 services wired with entrypoint
- [ ] docker-compose.yml stripped of hardcoded secrets
- [ ] All containers show successful injection in logs
