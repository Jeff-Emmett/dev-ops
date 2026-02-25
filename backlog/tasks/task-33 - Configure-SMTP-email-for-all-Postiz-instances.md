---
id: TASK-33
title: Configure SMTP email for all Postiz instances
status: Done
assignee: []
created_date: '2026-02-22 00:17'
updated_date: '2026-02-22 00:17'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add NodeMailer SMTP config to all 4 Postiz instances (VOTC, P2PF, CC, BCRG) via Mailcow / mail.rmail.online. Uses noreply@rmail.online, internal Docker network mailcowdockerized_mailcow-network, port 587 STARTTLS with NODE_TLS_REJECT_UNAUTHORIZED=0 for self-signed cert.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Completed 2026-02-22:
- Updated 4 compose files in dev-ops/netcup/postiz/ (votc, p2pf, cc, bcrg)
- EMAIL_PROVIDER=nodemailer, EMAIL_HOST=mailcowdockerized-postfix-mailcow-1
- All containers joined mailcowdockerized_mailcow-network
- EMAIL_PASS added to .env files on server
- Containers recreated and verified: logs show "Email service provider: nodemailer"
- Commit: 9087116 pushed to main
<!-- SECTION:NOTES:END -->
