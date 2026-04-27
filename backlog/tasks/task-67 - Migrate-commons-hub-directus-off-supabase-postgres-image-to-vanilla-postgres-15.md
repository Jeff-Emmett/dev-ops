---
id: TASK-67
title: >-
  Migrate commons-hub-directus off supabase-postgres image to vanilla
  postgres:15
status: In Progress
assignee: []
created_date: '2026-04-27 15:24'
updated_date: '2026-04-27 17:51'
labels:
  - infra
  - migration
  - cleanup
dependencies: []
references:
  - /home/jeffe/Github/dev-ops/netcup/uptime-kuma/
  - /opt/apps/supabase/ on netcup
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
commons-hub-directus currently uses `supabase-db` (image: `supabase/postgres:15.8.1.085`) and `supabase-rest` (PostgREST) as its data layer. The rest of the supabase stack (auth, storage, edge-functions, kong, studio, analytics, pooler, meta, realtime, vector) was decommissioned 2026-04-27 along with their unique images.

The remaining `supabase-db` and `supabase-rest` are the last things keeping the supabase repo alive on Netcup. Migrating Directus to a vanilla `postgres:15` image (and dropping PostgREST if Directus doesn't need it) lets us fully retire the supabase compose project and reclaim its named volumes.

**Current state (verified 2026-04-27):**
- `supabase-db` Up 3d, healthy, on `supabase_default` network (10.0.44.4)
- `supabase-rest` Up 26h, on both `supabase_default` and `traefik-public` (10.0.44.3) — serves 76 schema relations
- Directus env: `DB_HOST=supabase-db`, `DB_DATABASE=postgres`, `DB_USER=postgres`, `DB_CLIENT=pg`
- Both supabase databases exist: `postgres` (Directus data) and `_supabase` (internal)

**Why now:** removes ~1.2GB of supabase-specific Postgres image bulk and lets the supabase compose project be archived from `/opt/apps/`.

**Why not urgent:** the current setup works fine. This is hygiene, not a fix.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 pg_dump of `postgres` database from supabase-db captured to backup location
- [ ] #2 New `commons-hub-directus-db` (postgres:15-alpine) container running with the dumped data restored
- [ ] #3 Directus env updated to point at new DB host, container restarts cleanly, login + content load work
- [x] #4 Determine whether `supabase-rest` is consumed by anything other than Directus internals — if not, decommission it too
- [ ] #5 Old supabase-db + supabase-rest containers stopped and confirmed removable
- [ ] #6 supabase compose project at `/opt/apps/supabase/` archived (or deleted) from server and removed from any inventory
- [ ] #7 Removal of remaining supabase images: supabase/postgres:15.8.1.085 and postgrest/postgrest:v14.8 (if not referenced elsewhere)
- [x] #8 Phase 1: stop+remove `supabase-rest`, disable `commons-hub-supabase/docker-compose.override.yml`, verify website + Directus admin healthy
- [ ] #9 Phase 2: confirm Directus only needs vanilla Postgres extensions (audit pg_extension list against Directus needs)
- [ ] #10 Phase 3: clean up stale Supabase imports in commons-hub-website source (lib/supabase/, middleware.ts, app/protected/, app/auth/confirm/) — separate frontend concern
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**2026-04-27 — Phase 1 complete**

Path corrections from original description:
- Compose project lives at `/opt/apps/commons-hub-supabase/` (not `/opt/apps/supabase/`)
- Override file at `/opt/apps/commons-hub-supabase/docker-compose.override.yml` defined the public Traefik routes for `commons-hub-api.jeffemmett.com/{rest,auth,storage}/v1`

Dependency map verified before any destructive moves:
- `commons-hub-website` (Next.js, deployed as `commons-hub-web` container) has stale Supabase imports in middleware.ts and lib/supabase/ — but auth/storage routes have been 404 for days because those containers were exited before the 2026-04-27 cleanup. Site still works because public paths (`/`, `/page`, `/category`, `/post`, `/booking`, `/linktree`, `/events`, `/pitchdecks`, `/brochures`, `/auth/*`, `/login`) are whitelisted in middleware redirect logic.
- `supabase-rest` PostgREST: zero log entries in 24h+ except schema-cache reloads. Zero hits in Traefik logs. Only TS reference is the unused `components/tutorial/fetch-data-steps.tsx` component (not imported into any app route).

Phase 1 actions:
1. `docker stop supabase-rest && docker rm supabase-rest` — site (200), admin (302), Directus (Up 2d) all unaffected
2. `mv /opt/apps/commons-hub-supabase/docker-compose.override.yml{,.disabled-2026-04-27}` — prevents accidental `compose up` from recreating dead services

Left alone:
- `supabase-db` still running (Directus depends on it) — Phase 2 work
- 8 alternative compose files in `commons-hub-supabase/` (caddy/envoy/nginx/pg17/rustfs/s3 variants) — leave for now, archive when project is fully retired in Phase 3
<!-- SECTION:NOTES:END -->
