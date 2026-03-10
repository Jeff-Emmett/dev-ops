---
id: TASK-40
title: Wire Postiz instances to Infisical (4 services)
status: Done
assignee: []
created_date: '2026-02-23 20:00'
updated_date: '2026-03-10 21:21'
labels:
  - infisical
dependencies:
  - TASK-39
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate all 4 Postiz instances to Infisical using the volume-mount wrapper pattern.

Services: postiz-bcrg, postiz-cc, postiz-p2pf, postiz-votc
Each gets its own Infisical project with JWT_SECRET, DB password, social API keys, SMTP credentials.

For each:
1. Create Infisical project
2. Push secrets from .env
3. Mount wrapper + override entrypoint in docker-compose.yml
4. Deploy and verify
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 4 Infisical projects created (postiz-bcrg, postiz-cc, postiz-p2pf, postiz-votc)
- [ ] #2 All secrets migrated for each instance
- [ ] #3 Volume-mount wrapper configured in all 4 compose files
- [ ] #4 All 4 instances verified via container logs
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2026-03-10: all 3 active instances (main, cc, p2pf) have Infisical on server. Repo compose files match server exactly. BCRG and VOTC shut down. Legacy at /opt/apps/postiz/ not running (shares container name with main).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All 3 active Postiz instances fully wired to Infisical on Netcup server and repo compose files synced:

- **Main** (`demo.rsocials.online`) → Infisical project `postiz-main`
- **CC** (`socials.crypto-commons.org`) → Infisical project `postiz-crypto-commons`
- **P2PF** (`socials.p2pfoundation.net`) → Infisical project `postiz-p2pfoundation`

Inactive instances (BCRG shut down, VOTC shut down, Legacy conflicts with Main container name — not running). No remaining Postiz instances need wiring.

Server compose files match repo exactly (verified via diff). All use entrypoint-wrapper.sh volume mount pattern with Infisical secret injection at startup.
<!-- SECTION:FINAL_SUMMARY:END -->
