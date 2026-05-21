---
id: TASK-LOW.11
title: 'Vaultwarden: Bitwarden client connection'
status: To Do
assignee: []
created_date: '2026-05-12 20:56'
updated_date: '2026-05-12 20:56'
labels:
  - infra
  - task-82
dependencies:
  - TASK-LOW.9
parent_task_id: TASK-LOW
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-82 AC #10 — Connect at least one official Bitwarden client to the self-hosted Vaultwarden instance.

**Depends on:** First admin user account exists (AC #7).

**Steps (any one suffices but all three preferred):**
- Browser extension: Settings → Self-hosted environment → Server URL: https://passwords.jeffemmett.com → Save → Login
- Mobile (iOS/Android): Login screen → settings cog → same URL
- Desktop: File → Settings → Server URL → same → Login
- CLI: `bw config server https://passwords.jeffemmett.com && bw login`

**Verify:** Each client successfully fetches the vault, password autofill works on a test site.

**Why:** Acceptance bar — the whole point of self-hosting is that the official clients connect transparently. Any connection failure surfaces compatibility issues early.
**Parent:** TASK-82
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Browser extension connected and vault syncs
- [ ] #2 Mobile client connected (iOS or Android)
- [ ] #3 At least one autofill test on a real site passes
<!-- AC:END -->
