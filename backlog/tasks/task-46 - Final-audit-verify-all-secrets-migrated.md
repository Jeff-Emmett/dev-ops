---
id: TASK-46
title: Final audit — verify all secrets migrated, clean .env files
status: To Do
assignee: []
created_date: '2026-02-23 20:00'
updated_date: '2026-02-23 20:00'
labels: [infisical, audit]
dependencies: ['TASK-38', 'TASK-40', 'TASK-41', 'TASK-42', 'TASK-43', 'TASK-44', 'TASK-45']
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Final verification pass after all services are migrated to Infisical.

Steps:
1. Run audit-secrets.sh across all Netcup compose files — flag any remaining unmanaged secrets
2. For each migrated service: back up .env as .env.pre-infisical, strip to only INFISICAL_CLIENT_ID/SECRET
3. Update inventory.yaml with final migration status for all services
4. Verify all Machine Identities have viewer-only scope on their project
5. Run verify-injection.sh for all containers — confirm zero failures
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [ ] audit-secrets.sh returns zero unmanaged secrets
- [ ] All .env files backed up and stripped
- [ ] inventory.yaml fully updated (all services show `migrated` or `skip`)
- [ ] All machine identities have minimal (viewer) permissions
- [ ] verify-injection.sh shows 100% pass rate
