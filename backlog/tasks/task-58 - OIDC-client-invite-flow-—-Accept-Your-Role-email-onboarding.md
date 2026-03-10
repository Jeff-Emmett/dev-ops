---
id: TASK-58
title: OIDC client invite flow — "Accept Your Role" email onboarding
status: Done
assignee: []
created_date: '2026-03-10 01:02'
updated_date: '2026-03-10 01:02'
labels:
  - encryptid
  - oidc
  - onboarding
dependencies: []
references:
  - rspace-online/src/encryptid/schema.sql
  - rspace-online/src/encryptid/db.ts
  - rspace-online/src/encryptid/server.ts
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Admin invites users to OIDC-connected apps (e.g. Postiz) from /admin/oidc. Branded email arrives, recipient registers or signs in at /oidc/accept, email auto-added to client allowlist, success page links to the app.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Admin can send invite from /admin/oidc per client
- [x] #2 Branded email sent with client app name and optional message
- [x] #3 Accept page at /oidc/accept with register + sign-in tabs
- [x] #4 Invite claim auto-adds email to OIDC client allowed_emails
- [x] #5 Success page shows link to the app
- [x] #6 Pending invites visible per client in admin UI
- [x] #7 Tested end-to-end: jeff@jeffemmett.com → postiz-cc
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Changes

### Schema (`schema.sql`)
- Added `client_id TEXT REFERENCES oidc_clients(client_id)` to `identity_invites`

### DB layer (`db.ts`)
- `StoredIdentityInvite` + `mapInviteRow` + `createIdentityInvite` updated with `clientId`
- Added `getIdentityInvitesByClient(clientId)`

### Server (`server.ts`)
- `POST /api/admin/oidc/clients/:clientId/invite` — admin-gated, sends branded email
- `GET /api/admin/oidc/clients/:clientId/invites` — list invites per client
- `GET /api/invites/identity/:token/info` — returns `clientId`, `clientName`, `clientAppUrl`
- `POST /api/invites/identity/:token/claim` — auto-adds email to OIDC allowlist
- `GET /oidc/accept?token=xxx` — two-tab accept page (register / sign in)
- Admin UI updated with invite input, "Show Invites" button, status badges

### Postfix fix
- All 3 Postiz OIDC clients updated: redirect_uri changed from `/api/auth/generic-oauth/callback` to `/settings` (matching Postiz's actual OAuth implementation)

### Commits
- `c789481` feat(rwallet): link external wallets via EIP-6963 + SIWE (bundled)
- `d861c0a` fix(encryptid): harden wallet link flow + add device_registration type
- `8723aae` fix(encryptid): show success page instead of auto-OIDC redirect
<!-- SECTION:FINAL_SUMMARY:END -->
