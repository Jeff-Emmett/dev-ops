---
id: task-57
title: Wire all live containers to auto-deploy webhook
status: Done
assignee: ['@claude']
created_date: '2026-02-28 00:30'
labels: [infrastructure, auto-deploy]
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Audit all running Docker containers on Netcup RS 8000 and ensure every site/app with a git repo and docker-compose file is wired up to the deploy-webhook for automatic deployment on push.
<!-- SECTION:DESCRIPTION:END -->

## Plan

<!-- SECTION:PLAN:BEGIN -->
1. Cross-reference running containers, /opt/websites/ and /opt/apps/ directories, webhook.py REPOS dict, and Gitea webhook configs
2. Add missing repos to webhook.py
3. Create Gitea webhooks for repos that don't have them
4. Rebuild deploy-webhook container
5. Push deploy-webhook repo to Gitea
<!-- SECTION:PLAN:END -->

## Acceptance Criteria

- [x] All repos in /opt/websites/ and /opt/apps/ with running containers are in webhook.py REPOS dict
- [x] All repos have Gitea webhooks pointing to deploy.jeffemmett.com
- [x] deploy-webhook container rebuilt and running with new config
- [x] deploy-webhook repo pushed to Gitea

## Notes

<!-- SECTION:NOTES:BEGIN -->
- Audit found 62 repos missing from auto-deploy (was 54 configured, now 116)
- 30 repos had Gitea webhooks but no webhook.py entry
- 32 repos needed both webhook.py entry AND Gitea webhook creation
- 1 name mismatch: Gitea repo `personal-knowledge-management-network` -> dir `/opt/apps/pkmn`
- deploy-webhook was not previously in git; initialized repo and pushed to Gitea as `jeffemmett/deploy-webhook`
- Skipped canvas-website-staging (same Gitea repo as canvas-website, different deploy path)
- Third-party apps without custom repos (postiz, affine, etc.) excluded — they use `docker compose pull` not git-based deploys
<!-- SECTION:NOTES:END -->
