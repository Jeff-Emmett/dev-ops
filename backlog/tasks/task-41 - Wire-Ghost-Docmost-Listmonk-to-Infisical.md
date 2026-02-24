---
id: TASK-41
title: Wire Ghost, Docmost, Listmonk to Infisical
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
Migrate content platform services to Infisical using the volume-mount wrapper.

Services:
- Ghost cosmolocal + crypto-commons (Node.js, DB + SMTP secrets)
- Docmost + docmost-cl (Node.js, APP_SECRET + DB)
- Listmonk (Go, DB + SMTP)

Use wrapper pattern for all. Listmonk may need curl+jq fallback since it's a Go binary.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [ ] 5 Infisical projects created
- [ ] All secrets migrated
- [ ] Wrapper mounted in all compose files
- [ ] All services verified
