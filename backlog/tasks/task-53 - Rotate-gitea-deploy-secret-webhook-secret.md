---
id: TASK-53
title: Rotate gitea-deploy-secret webhook secret
status: To Do
assignee: []
created_date: '2026-02-25 22:46'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The webhook secret `gitea-deploy-secret-2025` is exposed in git history across multiple repos (canvas-website, canvas-website-version-reversion, immich-docker CLAUDE.md files). CLAUDE.md files have been removed from tracking and global gitignore added, but the secret itself needs rotation.

Steps:
1. Generate new webhook secret and store in Infisical (claude-ops project)
2. Update /opt/deploy-webhook/webhook.py on Netcup with new secret
3. Update Gitea webhooks for all 3 auto-deploying repos (decolonize-time-website, mycofi-earth-website, games-platform)
4. Verify all webhooks still trigger correctly
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 New webhook secret generated and stored in Infisical
- [ ] #2 webhook.py on Netcup updated with new secret
- [ ] #3 All 3 Gitea webhooks updated
- [ ] #4 Test push triggers successful deploy
<!-- AC:END -->
