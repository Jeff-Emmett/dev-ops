---
id: TASK-47
title: 'Harden backup system — MariaDB dumps, email alerts, Ansible playbook'
status: Done
assignee: []
created_date: '2026-02-25 01:32'
updated_date: '2026-02-25 01:32'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Comprehensive backup system hardening: fix broken Immich/CalCom backups, add MariaDB/MySQL database dumps, enable Hetzner Storage Box as second offsite target, add daily health check with email alerting via Mailcow SMTP, and create Ansible playbook for full server rebuild from scratch.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Fix broken Immich backup (docker-compose v1 → v2, service name)
- [x] #2 Remove dead CalCom cron entries and clean up empty backups
- [x] #3 Add MariaDB/MySQL auto-detection and dumps to nightly backup
- [x] #4 Enable Hetzner Storage Box as second offsite target
- [x] #5 Create backup health check script with email alerting
- [x] #6 Create Ansible playbook (6 roles: base, users, ssh, docker, firewall, backup)
- [x] #7 Dry-run Ansible playbook against live server (38 ok, 0 failed)
- [x] #8 Full end-to-end test of all backup components
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Completed 2026-02-25. All components tested end-to-end:
- Immich: 618MB dumps (was 20 bytes)
- ERPNext MariaDB: 15MB, Mailcow MySQL: 5.1MB
- Hetzner sync verified
- Email alerts to jeff@jeffemmett.com confirmed
- Ansible dry-run: 38 ok, 0 failed
- Committed to dev-ops repo (d5151ac), pushed to Gitea
<!-- SECTION:NOTES:END -->
