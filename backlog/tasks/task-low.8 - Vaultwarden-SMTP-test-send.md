---
id: TASK-LOW.8
title: 'Vaultwarden: SMTP test send'
status: Done
assignee: []
created_date: '2026-05-12 20:56'
updated_date: '2026-05-14 20:37'
labels:
  - infra
  - task-82
dependencies: []
parent_task_id: TASK-LOW
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-82 AC #6 — Confirm SMTP path from container → Mailcow → inbox works end-to-end.

**Steps:**
1. Login to https://passwords.jeffemmett.com/admin with plaintext passphrase from `~/.secrets/private/vaultwarden_admin_passphrase_jeff.txt`
2. Settings → SMTP → 'Send test email' button
3. Verify arrival at jeffemmett@gmail.com (sender: claude@jeffemmett.com)

**Why:** Confirms invitation emails will actually deliver before first user invite (AC #7).
**Parent:** TASK-82
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Test email sent successfully via admin panel
- [x] #2 Email arrives at jeffemmett@gmail.com
- [x] #3 From: claude@jeffemmett.com confirmed in headers
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
SMTP path verified end-to-end 2026-05-14. Mailcow's mounted leaf cert has CA:TRUE in basicConstraints (RFC 5280 violation) and lacks mail.rmail.online in SAN — rustls/Lettre rejected with `CaUsedAsEndEntity`. Workaround applied: `SMTP_ACCEPT_INVALID_CERTS=true` + `SMTP_ACCEPT_INVALID_HOSTNAMES=true` in VW compose. Proper fix (regenerate Mailcow cert via ACME) tracked separately.
<!-- SECTION:NOTES:END -->
