---
id: TASK-37
title: Wire payment-infra to Infisical (30+ secrets)
status: Done
assignee: []
created_date: '2026-02-23 20:00'
updated_date: '2026-03-10 21:34'
labels:
  - infisical
  - infrastructure
dependencies:
  - TASK-34
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate payment-infra secrets to Infisical. Most complex service: 8 sub-services share ~30 secrets including blockchain keys, payment processor credentials, and DB passwords.

Steps:
1. Create Infisical project `payment-infra`
2. Categorize secrets by sub-service (may need secret paths: /api, /worker, /gateway, etc.)
3. Push all secrets to Infisical
4. Add Node.js entrypoint to each service's Dockerfile
5. Update docker-compose.yml
6. Deploy and verify all 8 services
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Infisical project `payment-infra` created
- [x] #2 All 30+ secrets migrated (organized by path if needed)
- [x] #3 All 8 services wired with entrypoint
- [x] #4 docker-compose.yml stripped of hardcoded secrets
- [ ] #5 All containers show successful injection in logs
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-03-10: Infisical project had 38 secrets pre-existing. Added DATABASE_URL (constructed with docker hostname), plus 7 empty placeholders for unused integrations (Cybrid, PayRam, Onramper, Transak webhook). Total: 46 secrets.

Created docker-compose.prod.yaml overlay using volume-mount wrapper pattern. All 13 custom Node.js services wired. Postgres gets DB_PASSWORD from .env (no curl/jq in alpine). Gateway disabled in prod (shared Traefik).

Not yet deployed to Netcup — compose is deployment-ready. AC #5 (container log verification) deferred to deployment.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All 46 secrets in Infisical project `payment-infra` (prod environment). Production compose overlay (`docker-compose.prod.yaml`) created with Infisical entrypoint-wrapper.sh volume-mount pattern for all 13 custom Node.js services. `.env` on Netcup needs only: INFISICAL_CLIENT_ID, INFISICAL_CLIENT_SECRET, DB_PASSWORD.\n\nDeployment command: `docker compose -f docker-compose.yml -f docker-compose.prod.yaml up -d --build`\n\nCommitted as 862344e on payment-infra dev branch.
<!-- SECTION:FINAL_SUMMARY:END -->
