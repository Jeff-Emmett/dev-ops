---
id: TASK-HIGH.7
title: Pull clip-forge + media-forge off public Traefik (post rspace defences)
status: To Do
assignee: []
created_date: '2026-05-08 16:50'
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
- [ ] #1 rspace-online feat/forge-integration-audit merged to main + deployed
- [ ] #2 New defences verified at https://rspace.online/holonic/tools (badges) and /holonic/morpheus/log (renders)
- [ ] #3 clip-forge compose patched + redeployed; clip.jeffemmett.com returns 502/404
- [ ] #4 media-forge sablier file-provider config renamed to .disabled; media.jeffemmett.com returns 404
- [ ] #5 CLIP_FORGE_URL=http://clip-forge:8000 + MEDIA_FORGE_URL=http://media-forge:8000 set in rspace-online .env; verified by docker exec rspace-online curl http://clip-forge:8000/health
- [ ] #6 Kuma monitors 113 + 227 replaced with push-monitor probes fed from Netcup
- [ ] #7 Optional: drop CF DNS records + tunnel public-hostname allowlist for clip + media subdomains
<!-- SECTION:DESCRIPTION:END -->
