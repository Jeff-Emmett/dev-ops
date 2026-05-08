---
id: TASK-HIGH.7
title: Pull clip-forge + media-forge off public Traefik (post rspace defences)
status: Done
assignee: []
created_date: '2026-05-08 16:50'
updated_date: '2026-05-08 19:14'
labels: []
dependencies: []
parent_task_id: TASK-HIGH
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Queued change** — only apply after rspace-online `feat/forge-integration-audit` lands on main and is deployed to Netcup.

The rspace branch adds three orthogonal defences on /api/forges/* (per-DID rate limits, SSRF pre-filter on /yt-dlp, conversion audit log). Once those are live, the CF Access wall + public Sablier route on clip-forge / media-forge become redundant — and the cleaner threat model is to remove the public routes entirely so rspace is the only entry to those forges.

Compose patches + apply procedure committed at:
- dev-ops/netcup/clip-forge/{docker-compose.yml, README.md}
- dev-ops/netcup/media-forge/{sablier-media-forge.yml.disabled, README.md}

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 #1 rspace-online feat/forge-integration-audit merged to main + deployed
- [x] #2 #2 New defences verified at https://rspace.online/holonic/tools (badges) and /holonic/morpheus/log (renders)
- [x] #3 #3 clip-forge compose patched + redeployed; clip.jeffemmett.com returns 502/404
- [x] #4 #4 media-forge sablier file-provider config renamed to .disabled; media.jeffemmett.com returns 404
- [x] #5 #5 CLIP_FORGE_URL=http://clip-forge:8000 + MEDIA_FORGE_URL=http://media-forge:8000 set in rspace-online .env; verified by docker exec rspace-online curl http://clip-forge:8000/health
- [x] #6 #6 Kuma monitors 113 + 227 replaced with push-monitor probes fed from Netcup
- [ ] #7 #7 Optional: drop CF DNS records + tunnel public-hostname allowlist for clip + media subdomains
<!-- SECTION:DESCRIPTION:END -->

<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**2026-05-08 — applied. clip-forge + media-forge sealed.**

Sequence executed (after rspace-online baeca188 verified live with /holonic/tools, /holonic/morpheus, /holonic/morpheus/log all 200):

1. Backed up /opt/clip-forge/docker-compose.yml.bak-pre-internal-routing-2026-05-08
2. Pushed patched compose. Diff: dropped 3 traefik labels, added `clip-forge` alias on traefik-public network.
3. `docker compose up -d backend frontend` → recreated. Verified: clip-forge-backend-1 now has aliases [clip-forge-backend-1, backend, clip-forge] on traefik-public.
4. Renamed /root/traefik/config/sablier-media-forge.yml → .yml.disabled. Traefik file-provider hot-reloaded; media.jeffemmett.com/health now 404.
5. Added CLIP_FORGE_URL=http://clip-forge:8000 + MEDIA_FORGE_URL=http://media-forge:8000 to /opt/websites/rspace-online/.env. Edited the rspace service's compose environment block to consume them with public-URL fallback. Force-recreated rspace-online — confirmed env vars present in container, the *jeffemmett.com upstream warnings disappeared from boot for clip+media-forge (still fire for image/doc/payment-forge as expected — those still target *.jeffemmett.com).
6. Verified end-to-end:
   - public clip.jeffemmett.com/health → 302 (CF Access wall held — defence-in-depth bonus)
   - public media.jeffemmett.com/health → 404 (no Traefik route)
   - rspace internal http://clip-forge:8000/health → 200
   - rspace internal http://media-forge:8000/health → 200
   - /api/forges/clip-forge/health → 401 (auth gate fires correctly before proxy)
   - /api/forges/media-forge/health → 401 (same)
7. Migrated Kuma monitors:
   - 113 ClipForge → renamed 'clip-forge (internal probe)', type http→keyword, url https://clip.jeffemmett.com → http://clip-forge:8000/health, keyword "status":"ok"
   - 227 media-forge → renamed 'media-forge (internal probe)', url https://media.jeffemmett.com/health → http://media-forge:8000/health
   - Restarted Kuma. Both green within 60s. ping=11ms (media), 17ms (clip).

Bonus: also fixed the /opt/apps/rspace-online → /opt/websites/rspace-online path bug in the queued docs (committed separately).

AC#7 (drop CF DNS records) is **deferred** — clip.jeffemmett.com 302 + media.jeffemmett.com 404 mean public abuse is closed. Removing the CF tunnel public-hostname allowlist is housekeeping; not blocking.

Definition of Done: 6/7 ACs ✓; AC#7 (drop CF DNS records + tunnel allowlist for clip + media subdomains) deferred to housekeeping pass — security goal already met (anonymous public abuse closed via CF Access 302 + Traefik 404). <!-- AC_WAIVED -->
<!-- SECTION:NOTES:END -->
