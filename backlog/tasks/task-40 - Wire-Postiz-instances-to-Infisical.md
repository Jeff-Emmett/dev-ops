---
id: TASK-40
title: Wire Postiz instances to Infisical (4 services)
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
Migrate all 4 Postiz instances to Infisical using the volume-mount wrapper pattern.

Services: postiz-bcrg, postiz-cc, postiz-p2pf, postiz-votc
Each gets its own Infisical project with JWT_SECRET, DB password, social API keys, SMTP credentials.

For each:
1. Create Infisical project
2. Push secrets from .env
3. Mount wrapper + override entrypoint in docker-compose.yml
4. Deploy and verify
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [ ] 4 Infisical projects created (postiz-bcrg, postiz-cc, postiz-p2pf, postiz-votc)
- [ ] All secrets migrated for each instance
- [ ] Volume-mount wrapper configured in all 4 compose files
- [ ] All 4 instances verified via container logs
