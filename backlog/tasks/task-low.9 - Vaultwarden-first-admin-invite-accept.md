---
id: TASK-LOW.9
title: 'Vaultwarden: first admin invite + accept'
status: To Do
assignee: []
created_date: '2026-05-12 20:56'
updated_date: '2026-05-12 20:56'
labels:
  - infra
  - task-82
dependencies:
  - TASK-LOW.8
parent_task_id: TASK-LOW
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-82 AC #7 — Create first owner user and accept invitation via email link.

**Depends on:** SMTP test (AC #6) passing first.

**Steps:**
1. /admin → Users → Invite user → jeffemmett@gmail.com
2. Open invite email, click activation link
3. Set master password (store in KeePass)
4. Login at https://passwords.jeffemmett.com
5. Create first Organization for the team
6. Add Collections + share creds

**Why:** Establishes the actual usable account. Until this runs, the vault has no users.
**Parent:** TASK-82
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Invite sent and email received
- [ ] #2 Account activated with master password set
- [ ] #3 Login to web vault successful
- [ ] #4 First Organization created
<!-- AC:END -->
