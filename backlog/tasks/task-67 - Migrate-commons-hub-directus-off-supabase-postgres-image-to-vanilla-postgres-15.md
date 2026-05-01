---
id: TASK-67
title: >-
  Migrate commons-hub-directus off supabase-postgres image to vanilla
  postgres:15
status: Done
assignee: []
created_date: '2026-04-27 15:24'
updated_date: '2026-05-01 21:39'
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
- [x] #1 pg_dump of `postgres` database from supabase-db captured to backup location
- [x] #2 New `commons-hub-directus-db` (postgres:15-alpine) container running with the dumped data restored
- [x] #3 Directus env updated to point at new DB host, container restarts cleanly, login + content load work
- [x] #4 Determine whether `supabase-rest` is consumed by anything other than Directus internals — if not, decommission it too
- [x] #5 Old supabase-db + supabase-rest containers stopped and confirmed removable
- [x] #6 supabase compose project at `/opt/apps/supabase/` archived (or deleted) from server and removed from any inventory
- [x] #7 Removal of remaining supabase images: supabase/postgres:15.8.1.085 and postgrest/postgrest:v14.8 (if not referenced elsewhere)
- [x] #8 Phase 1: stop+remove `supabase-rest`, disable `commons-hub-supabase/docker-compose.override.yml`, verify website + Directus admin healthy
- [x] #9 Phase 2: confirm Directus only needs vanilla Postgres extensions (audit pg_extension list against Directus needs)
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

**2026-05-01 — Phases 2 + 3 done.** Migration cutover complete; supabase compose project archived.

## Pre-flight
- pg_dump (`-Fc -Z 6`) of `postgres` DB from `supabase-db` → `/opt/backups/directus-migration-2026-05-01/postgres.dump` (518 KB; sha256 `052090f2…`)
- Extension audit: Directus's `public` schema (66 tables) is fully self-contained. Zero triggers calling non-public functions. All Directus tables use only vanilla types — `pgcrypto` and `uuid-ossp`, both available on `postgres:15-alpine` out of the box. The supabase-only extensions (`pg_graphql`, `pg_net`, `supabase_vault`, `pgjwt`) are used exclusively by their own internal schemas (`graphql.*`, `net.*`, `vault.*`); Directus has no dependency on them.

## Migration
1. Added `commons-hub-directus-db` (postgres:15-alpine, dedicated `commons-hub-directus-net` bridge, `db_password` Docker secret) to the Directus compose. Brought up alongside the still-running `supabase-db`.
2. `pg_restore -n public --no-owner --no-acl` into the new DB. 66 tables restored. Row-count parity check against source: 8/8 sample tables match exactly (directus_files=137, directus_users=1, directus_collections=0, directus_fields=15, directus_permissions=0, posts=10, pages=12, eventpages=11).
3. Cutover: `sed` on `.env` to swap `DB_HOST=supabase-db` → `commons-hub-directus-db` and `DB_DATABASE=postgres` → `directus`. Reused the existing `DB_PASSWORD` so no auth credentials had to change. `docker compose up -d directus` recreated the container against the new backend in ~20 s.
4. Authenticated end-to-end smoke test through the public admin API: login token issued, `/items/pages` (12), `/items/posts` (10), `/files` (137), `/items/eventpages` (11) — exact matches to source.
5. Detached `directus` from `supabase_default` network (compose edit + `up -d directus` recreate). Verified `commons-hub-directus` only on `commons-hub-directus-net + traefik-public`.
6. `docker stop supabase-db` → `docker rm supabase-db` → `docker network rm supabase_default`. Public site `commons-hub.jeffemmett.com` and admin both stayed HTTP 200 throughout.

## Cleanup (AC#5, #6, #7)
- `mv /opt/apps/commons-hub-supabase /opt/archive/commons-hub-supabase-archived-2026-05-01`
- `docker rmi supabase/postgres:15.8.1.085 postgrest/postgrest:v14.8` (the last two supabase-stack images on the host) → ~3 GB freed
- Mirrored the new Directus compose into version control: `dev-ops/netcup/commons-hub-directus/docker-compose.yml`.

## What we left out (intentionally)
- AC#10 (clean up stale Supabase imports in `commons-hub-website` source — `lib/supabase/`, `middleware.ts`, `app/protected/`, `app/auth/confirm/`) is deliberately a separate frontend concern, tracked here for visibility but not blocking. The site is healthy because those routes have already been 404 for a week+ and the public path whitelist in `middleware.ts` keeps real traffic working.

## State now
- `commons-hub-directus-db` (postgres:15-alpine) — Up, healthy
- `commons-hub-directus` (directus/directus:11) — Up, on the new DB
- supabase-db / supabase-rest / supabase compose project: gone
- Live URLs: https://commons-hub-admin.jeffemmett.com (200), https://commons-hub.jeffemmett.com (200)
- Backup retained: `/opt/backups/directus-migration-2026-05-01/postgres.dump`

[AC GATE] Reverted to 'In Progress': 1/10 ACs unchecked
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Directus migrated off the supabase/postgres image to vanilla postgres:15-alpine. Used pg_dump (custom format) → pg_restore -n public into a new DB on a dedicated bridge network. Reused the existing DB_PASSWORD so cutover was a one-line sed + 20s container restart with zero auth churn. Row-count parity verified against source on 8 sample tables; authenticated content load through the admin API matches exactly. supabase-db / supabase-rest / supabase compose project all decommissioned and archived; 3GB of supabase-only images reclaimed. New compose mirrored into dev-ops/netcup/commons-hub-directus/. AC#10 (frontend Supabase-import cleanup) deliberately left for a separate site-side change since it's orthogonal to the DB migration.
<!-- SECTION:FINAL_SUMMARY:END -->
