---
id: TASK-65
title: Migrate headscale-deploy secrets to Infisical
status: Done
assignee: []
created_date: '2026-03-22 00:40'
updated_date: '2026-03-22 00:40'
labels:
  - infisical
  - security
  - headscale
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate HEADSCALE_API_KEY and HEADPLANE_COOKIE_SECRET from hardcoded .env to Infisical runtime injection. HEADPLANE_BASIC_AUTH stays in .env (Traefik needs it at compose-time).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Infisical project 'headscale' created with machine identity
- [x] #2 COOKIE_SECRET and ROOT_API_KEY stored in Infisical
- [x] #3 headplane uses Infisical wrapper for secret injection at runtime
- [x] #4 Server .env contains only Infisical creds + BASIC_AUTH hash (no plaintext secrets)
- [x] #5 Old hardcoded config.yaml removed from server
- [x] #6 headscale nodes unaffected by migration
- [x] #7 headplane UI accessible via vpn-admin.jeffemmett.com
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Completed: Headscale Infisical Migration

### What changed
- Created Infisical project `headscale` with machine identity `headscale-deploy`
- Stored `COOKIE_SECRET` (32-char) and `ROOT_API_KEY` in Infisical prod environment
- Switched headplane to `0.6.1-shell` image (required for wrapper script shell access)
- Added `headplane/start.sh` — generates config.yaml at runtime from Infisical-injected env vars (headplane 0.6.x requires config file, not env vars)
- Removed all hardcoded secrets from server `.env` and `headplane/config.yaml`

### Key discovery
Headplane 0.6.x reads secrets from `config.yaml`, not environment variables. Created a startup script that:
1. Receives env vars from Infisical wrapper
2. Generates `/tmp/headplane-config.yaml` with injected values
3. Sets `HEADPLANE_CONFIG_PATH` and execs node

### Architecture
```
.env (INFISICAL_CLIENT_ID, INFISICAL_CLIENT_SECRET, HEADPLANE_BASIC_AUTH)
  → entrypoint-wrapper.sh fetches COOKIE_SECRET + ROOT_API_KEY from Infisical
  → start.sh generates config.yaml from env vars
  → node /app/build/server/index.js reads config
```

### Files modified
- `docker-compose.yml` — Infisical wrapper, shell image, start.sh command
- `.env.example` — updated to Infisical pattern
- `headplane/config.yaml` — non-secret config only (committed to repo)
- `headplane/start.sh` — runtime config generator (new)

### Commits
- `a6aa39e` feat: migrate headplane secrets to Infisical
- `7faa393` fix: use headplane shell variant for Infisical wrapper compatibility
- `5b4b136` fix: correct node path for headplane shell variant
- `cb37a9a` fix: add headplane config.yaml (non-secret config only)
- `7f7b952` fix: add startup script to generate config from Infisical env vars
<!-- SECTION:FINAL_SUMMARY:END -->
