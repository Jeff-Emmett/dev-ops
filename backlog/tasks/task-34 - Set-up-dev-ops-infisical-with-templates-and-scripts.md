---
id: TASK-34
title: Set up dev-ops/infisical/ with templates and scripts
status: Done
assignee: ['@claude']
created_date: '2026-02-23 20:00'
updated_date: '2026-02-23 20:00'
labels: [infisical, infrastructure]
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the `/home/jeffe/Github/dev-ops/infisical/` directory with reusable tooling for Infisical secret management across all services.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [x] `templates/entrypoint-node.sh` — Node.js entrypoint (from rsocials-online)
- [x] `templates/entrypoint-bun.sh` — Bun entrypoint (from rspace-online)
- [x] `templates/entrypoint-python.sh` — Python entrypoint (from rswag)
- [x] `templates/entrypoint-wrapper.sh` — Auto-detect wrapper for third-party images
- [x] `scripts/create-project.sh` — Create Infisical project + machine identity
- [x] `scripts/migrate-env.sh` — Push .env secrets to Infisical
- [x] `scripts/audit-secrets.sh` — Scan compose files for unmanaged secrets
- [x] `scripts/verify-injection.sh` — Check container logs for injection confirmation
- [x] `README.md` — Setup guide and architecture overview
- [x] `inventory.yaml` — All services with migration status

## Notes

Completed as part of Infisical migration plan Phase 1.
