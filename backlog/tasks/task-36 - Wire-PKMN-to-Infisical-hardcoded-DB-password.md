---
id: TASK-36
title: Wire PKMN to Infisical (URGENT: hardcoded DB password)
status: Done
assignee: ['@claude']
created_date: '2026-02-23 20:00'
updated_date: '2026-02-24 01:40'
labels: [infisical, security, urgent]
dependencies: ['TASK-34']
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate Personal Knowledge Management Network (PKMN) secrets to Infisical. URGENT because the DB password was hardcoded in docker-compose.yml.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [x] Infisical project `pkmn-app` created with machine identity
- [x] All 20 secrets migrated to Infisical
- [x] Python entrypoint added to Dockerfile
- [x] docker-compose.prod.yml stripped of hardcoded secrets
- [x] Container logs show successful injection
- [x] .env.prod backed up as .env.prod.pre-infisical

## Notes

- Slug had to be `pkmn-app` (5 char minimum in Infisical)
- Cloudflare WAF (error 1010) blocks Python urllib User-Agent — must use curl for API calls
- Secrets pushed individually via curl (batch blocked by CF WAF on large payloads)
