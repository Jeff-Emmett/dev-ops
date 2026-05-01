---
id: TASK-81
title: Remove stale Supabase imports from commons-hub-website
status: To Do
assignee: []
created_date: '2026-05-01 21:39'
labels:
  - cleanup
  - frontend
  - tech-debt
dependencies: []
references:
  - task-67
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Spun out of TASK-67 (which migrated commons-hub-directus off supabase-postgres to vanilla postgres:15 on 2026-05-01).

The site is healthy because those routes have been 404 for a week+ and the public path whitelist in `middleware.ts` keeps real traffic working — but the dead code is a footgun for future contributors and a pretext for the unused @supabase/* npm deps to keep showing up in audits.

**What needs to go** (verified at TASK-67 close):
- `lib/supabase/` (browser + server clients)
- `middleware.ts` Supabase session refresh logic
- `app/protected/` (was Supabase auth gate; now dead)
- `app/auth/confirm/` (Supabase confirm email handler; dead)
- `components/tutorial/fetch-data-steps.tsx` (sample component referencing PostgREST; not imported by any app route)
- `@supabase/*` deps in package.json once the imports are gone

**Why not blocking:**
- All these routes have been returning 404 / falling through middleware to whitelisted paths since the supabase containers were stopped on 2026-04-27.
- Public site `commons-hub.jeffemmett.com` and admin `commons-hub-admin.jeffemmett.com` are healthy on the new vanilla postgres backend.

**Why low priority:** purely hygiene. No user-facing impact. Mostly a future-proofing move so a new contributor doesn't try to reactivate the dead auth pages.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 lib/supabase/ removed
- [ ] #2 middleware.ts has no @supabase imports; public path whitelist still works
- [ ] #3 app/protected/ + app/auth/confirm/ removed
- [ ] #4 components/tutorial/fetch-data-steps.tsx removed (or refactored to not reference PostgREST)
- [ ] #5 @supabase/* npm deps removed from package.json
- [ ] #6 Next.js build passes with no Supabase references
- [ ] #7 Site (public + admin) verified at HTTP 200 after deploy
<!-- AC:END -->
