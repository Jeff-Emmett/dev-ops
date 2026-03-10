---
id: TASK-61
title: Separate rMail deployment from rInbox on Netcup
status: Done
assignee: []
created_date: '2026-03-10 21:52'
updated_date: '2026-03-10 22:49'
labels:
  - infrastructure
  - rApps
  - analytics
dependencies: []
references:
  - ~/Github/rmail-online/src/app/layout.tsx
  - ~/Github/dev-ops/netcup/traefik/
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
rMail (rmail.online) currently shares the rInbox container and has no independent deployment on Netcup. It needs its own Docker Compose service, Traefik routing, and Umami analytics tracking (UUID: 7f37240e-547d-44c4-a966-4302098fd0e1 already registered in Umami DB).

Currently rmail.online serves directly from the rinbox container with rinbox's Umami UUID (ee5d541b-631a-41b8-a966-b5726199b942). The rmail-online Next.js app exists locally at ~/Github/rmail-online with the correct layout.tsx already updated, but has no /opt/apps/rmail-online or /opt/websites/rmail-online directory on the server.

Needs:
- Server directory at /opt/apps/rmail-online or /opt/websites/rmail-online
- Docker Compose with build config, Traefik labels for rmail.online
- Webhook config entry in deploy-webhook for auto-deploy
- Separate Traefik routing (currently rmail.online likely caught by rinbox's HostRegexp)
- Verify Umami tracking with site-specific UUID after deployment
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 rmail.online serves from its own container (not rinbox)
- [x] #2 Traefik routes rmail.online to the rmail container specifically
- [x] #3 Umami tracking uses rmail's own UUID 7f37240e-547d-44c4-a966-4302098fd0e1
- [x] #4 deploy-webhook auto-deploys rmail-online on git push
- [x] #5 rinbox.online still works independently after separation
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Completed: Separate rMail Landing Page

### Changes Made
1. **Created `landing/` directory** in rmail-online repo with:
   - `index.html` — Static landing page matching rStack dark theme pattern (rPhotos/rIdentity style)
   - `Dockerfile` — nginx:alpine serving static HTML
   - `nginx.conf` — SPA routing with `/health` endpoint

2. **Created `docker-compose.landing.yml`** — Standalone compose file with Traefik labels for `rmail.online` + `www.rmail.online` at priority 130

3. **Removed `rmail.online` from rinbox Traefik rule** in `docker-compose.prod.yml`

4. **Server deployment:**
   - Cloned repo to `/opt/apps/rmail-online/` on Netcup
   - Built and started `rmail_landing` container
   - Updated deploy-webhook `build_cmd` to use `-f docker-compose.landing.yml`

### Verification
- `curl https://rmail.online/` → Returns static landing page with Umami UUID `7f37240e-547d-44c4-a966-4302098fd0e1`
- `curl https://rmail.online/health` → `200 ok`
- `curl https://rinbox.online/` → Still works (redirects to rspace.online/rinbox as before)
- Deploy webhook updated and restarted
<!-- SECTION:FINAL_SUMMARY:END -->
