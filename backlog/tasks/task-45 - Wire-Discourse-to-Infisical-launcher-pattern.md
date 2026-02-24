---
id: TASK-45
title: Wire Discourse to Infisical (launcher pattern)
status: To Do
assignee: []
created_date: '2026-02-23 20:00'
updated_date: '2026-02-23 20:00'
labels: [infisical, special-case]
dependencies: ['TASK-39']
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate Discourse to Infisical. Discourse uses its own `./launcher` build system (not standard docker-compose), so a custom approach is needed.

Pattern:
1. Modify `app.yml` run section to curl Infisical API before Discourse boots
2. Use the `run:` hooks in app.yml to inject secrets as env vars
3. Alternatively, use a pre-launch script that fetches and exports secrets

Location: /opt/discourse/ on Netcup
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [ ] Infisical project `discourse` created
- [ ] All secrets migrated (SMTP, DB, admin, etc.)
- [ ] app.yml run hooks fetch secrets from Infisical
- [ ] Discourse boots with injected secrets after `./launcher rebuild`
