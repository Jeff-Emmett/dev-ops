---
id: TASK-8
title: Audit and Dockerize all website repos
status: Done
assignee: []
created_date: '2025-12-04 06:26'
updated_date: '2026-02-22 01:15'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Ensure all website repositories have proper Docker configurations for consistent deployment.

Check each repo for:
- Dockerfile (optimized, multi-stage build)
- docker-compose.yml with Traefik labels
- Health check endpoint
- Proper .dockerignore

Repos to audit:
- All *-website directories in /home/jeffe/Github/
- Any web apps that should be containerized

Standardize on the deployment pattern:
- Traefik labels for auto-discovery
- Join traefik-public network
- Health checks for monitoring
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All website repos have Dockerfile
- [x] #2 All website repos have docker-compose.yml with Traefik labels
- [x] #3 All containers have health checks defined
- [x] #4 Deployment documentation updated
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Audit completed 2026-02-22:

Results: 5 Ready, 37 Partial, 17 Missing, 10 Deployed-Only (no local repo)

Ready repos: valley-commons, cosmolocal-website, ebb-n-flow-website, worldplay-website, backlog-md

Most common gaps in Partial repos:
1. Missing .dockerignore (37 repos)
2. Missing health checks (22 repos)
3. Non-optimized single-stage Dockerfiles (13 repos)

Critical: 10 deployed apps have no local git repos (affine, docmost, listmonk, mattermost, etc.)

Priority fixes:
- Phase 1: Add git repos for deployed-only apps, Dockerfile for games-platform
- Phase 2: Add .dockerignore + health checks to high-traffic sites
- Phase 3: Bulk standardization of remaining Partial repos

Bulk Docker hardening completed 2026-02-21:
- Added .dockerignore to 60 repos (standardized template excluding node_modules, .git, .env*, backlog, build artifacts)
- Added Docker healthchecks to 44 docker-compose.yml files (port-appropriate: wget for Node.js, curl for Python)
- All 104 commits pushed to Gitea successfully
- Remaining gaps: 17 repos still need Dockerfiles, 10 deployed-only apps need local repos

Final audit 2026-02-21:

All 11 repos that appeared to need Dockerfiles already have them in subdirectories (multi-service repos with build contexts like backend/, frontend/, etc.)

43 deployed apps have no local repos, categorized:

THIRD-PARTY (pre-built images, no local repo needed - 13):
affine, docmost, glance, listmonk, mattermost, osrm-routing, pocket-id, twenty, twenty-rnetwork, twenty-votc, umami, uptime-kuma, headscale-deploy

STAGING/DEV VARIANTS of existing repos (3):
canvas-website-dev, canvas-website-staging, fcdm-website-new

MANAGED VIA dev-ops repo (2):
postiz, postiz-votc

CUSTOM APPS that could benefit from local repos (25):
auction-app, bam-baby-website, bondingcurve-website, claude-dev, cosmolocal-spec, defectfi, fungiflows, ghost-crypto-commons, mytmux.life-website, newsletter-api, newsletter-sync, p2p-blog, p2pwiki, p2pwikifr, pkmn, pkmn-graph, pocket-press, provider-registry, rbooks-online, rcart, rchoices-online, rdata-online, rforum-online, rnetwork-online-landing, rspace-widgets, swag-designer

Docker hardening summary:
- .dockerignore: 60 repos ✅
- Healthchecks: 44 repos ✅  
- Dockerfiles: All repos that need them have them ✅
- 25 custom deployed apps could use local repos (low priority, separate task)
<!-- SECTION:NOTES:END -->
