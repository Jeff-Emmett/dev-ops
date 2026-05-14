---
id: TASK-LOW.7
title: 'Vaultwarden: CF Access app on /admin*'
status: To Do
assignee: []
created_date: '2026-05-12 20:56'
updated_date: '2026-05-14 20:50'
labels:
  - infra
  - security
  - task-82
dependencies: []
parent_task_id: TASK-LOW
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-82 AC #4 — Create Cloudflare Access self-hosted app for passwords.jeffemmett.com/admin*, scoped to jeffemmett@gmail.com.

**Steps:**
1. CF dashboard → Zero Trust → Access → Applications → Add an application
2. Type: Self-hosted
3. Application name: 'Vaultwarden Admin'
4. Session duration: 24h
5. Application domain: passwords.jeffemmett.com / Path: /admin*
6. Policy: Allow if email == jeffemmett@gmail.com
7. Verify: visit https://passwords.jeffemmett.com/admin in incognito — should redirect to CF Access login

**Why:** /admin path uses ADMIN_TOKEN auth which is fine but adds defense-in-depth via CF identity layer. Public auth on / stays open so Bitwarden mobile/browser-ext clients work.

**Parent:** TASK-82
**Path on Netcup:** N/A — pure CF dashboard config
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 CF Access app created and visible in CF dashboard
- [ ] #2 Incognito probe of /admin redirects to CF Access login
- [ ] #3 Allow policy includes jeffemmett@gmail.com
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Attempted to scaffold via CF API (2026-05-14) using stored `CLOUDFLARE_API_TOKEN` from `~/.cloudflare-credentials.env`. Token returns `10000 Authentication error` against `/accounts/{id}/access/apps` — it has Zone:read, Worker, R2 scopes but no `Account.Access: Apps and Policies: Edit`.

Two paths to finish:

**(a) Dashboard — fastest for a one-shot (~3 min):**
   1. https://one.dash.cloudflare.com/ → Zero Trust → Access → Applications → Add
   2. Type: Self-hosted
   3. Name: `Vaultwarden Admin`, session 24h
   4. Domain: `passwords.jeffemmett.com`, Path: `/admin*` (or two entries `/admin` and `/admin/*`)
   5. Policy: Allow if email matches `jeffemmett@gmail.com`
   6. Save. Then in incognito: `https://passwords.jeffemmett.com/admin` should bounce to CF Access login.

**(b) API — if you'll do this kind of thing repeatedly:**
   Create a CF API token with `Account.Access: Apps and Policies: Edit` (and `Account.Access: Service Tokens: Edit` if you want service-token escape hatch later). Add to `~/.cloudflare-credentials.env` as `CLOUDFLARE_ACCESS_TOKEN=...`. Then run:
   ```bash
   set -a; . ~/.cloudflare-credentials.env; set +a
   ACCOUNT=0e7b3338d5278ed1b148e6456b940913
   APP=$(curl -s -X POST \
     -H "Authorization: Bearer ${CLOUDFLARE_ACCESS_TOKEN}" \
     -H "Content-Type: application/json" \
     "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT}/access/apps" \
     -d '{"name":"Vaultwarden Admin","domain":"passwords.jeffemmett.com/admin","type":"self_hosted","session_duration":"24h"}' | jq -r .result.id)
   curl -s -X POST \
     -H "Authorization: Bearer ${CLOUDFLARE_ACCESS_TOKEN}" \
     -H "Content-Type: application/json" \
     "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT}/access/apps/${APP}/policies" \
     -d '{"name":"Allow Jeff","decision":"allow","include":[{"email":{"email":"jeffemmett@gmail.com"}}]}'
   ```
   Note `domain` only accepts one host+path; for `/admin*` coverage you may want a second app for `/admin/*` (CF Access matches longest-prefix).
<!-- SECTION:NOTES:END -->
