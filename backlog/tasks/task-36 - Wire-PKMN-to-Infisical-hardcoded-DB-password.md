---
id: TASK-36
title: Wire PKMN to Infisical (URGENT: hardcoded DB password)
status: To Do
assignee: []
created_date: '2026-02-23 20:00'
updated_date: '2026-02-23 20:00'
labels: [infisical, security, urgent]
dependencies: ['TASK-34']
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate Personal Knowledge Management Network (PKMN) secrets to Infisical. URGENT because the DB password is hardcoded in docker-compose.yml.

Steps:
1. Create Infisical project `pkmn`
2. Push secrets from .env / compose to Infisical
3. Add Python entrypoint to Dockerfile
4. Update docker-compose.yml (only INFISICAL_* env vars)
5. Deploy and verify
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [ ] Infisical project `pkmn` created with machine identity
- [ ] All secrets migrated to Infisical (DB password, etc.)
- [ ] Python entrypoint added to Dockerfile
- [ ] docker-compose.yml stripped of hardcoded secrets
- [ ] Container logs show successful injection
- [ ] .env backed up as .env.pre-infisical
