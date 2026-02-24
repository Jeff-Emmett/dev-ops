---
id: TASK-44
title: Wire ERPNext to Infisical (sidecar pattern)
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
Migrate ERPNext to Infisical using the sidecar pattern. ERPNext has a complex multi-container setup where a simple entrypoint override won't work.

Pattern:
1. Add init container that fetches secrets from Infisical
2. Init container writes .env file to shared volume
3. Real ERPNext containers mount the shared volume and read .env
4. Init container runs before any app container starts

Location: /opt/erpnext/ on Netcup
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [ ] Infisical project `erpnext` created
- [ ] All secrets migrated (DB password, admin creds, etc.)
- [ ] Sidecar init container implemented
- [ ] Shared volume for .env injection working
- [ ] All ERPNext containers start with injected secrets
