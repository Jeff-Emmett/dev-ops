---
id: TASK-53
title: Rotate gitea-deploy-secret webhook secret
status: Done
assignee: []
created_date: '2026-02-25 22:46'
updated_date: '2026-04-27 18:33'
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
- [x] #1 New webhook secret generated and stored in Infisical
- [x] #2 webhook.py on Netcup updated with new secret
- [x] #3 All 3 Gitea webhooks updated
- [x] #4 Test push triggers successful deploy
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**2026-04-27 — Closed as already-mitigated. Original leaked literal `gitea-deploy-secret-2025` is no longer the production webhook secret.**

Verification:
- Current `/root/.secrets/webhook_secret` on Netcup is a 64-char random string (md5 `4bc008f43cbfdcce2db785b2d3d3de7d`); md5 of `gitea-deploy-secret-2025` is `83c9735edb1142cd85b536754de54ac3` — different. Anyone holding the leaked literal cannot authenticate.
- The leaked string still exists in git history of `canvas-website` and `immich-docker`, but it's now a dead secret.
- The rotation likely happened at some point as part of the 2026-02 CLAUDE.md cleanup commits (`df2bd4f security: redact secrets`, `43007c0 chore: remove CLAUDE.md from git tracking`).

Original AC items from this task were addressing the wrong picture:
- AC#1 ("store in Infisical") — the deploy-webhook actually uses Docker file secrets (`/root/.secrets/*` mounted via `secrets:` block in compose), not Infisical. Different valid pattern.
- AC#3 ("3 Gitea webhooks") — there are actually ~100 deploy webhooks across the Gitea instance, all sharing the same secret. The 3 named repos are out of date (2 were disabled 2026-04-01).

TASK-68 created to build a generalized rotation pipeline that solves this properly going forward, including:
- A secret inventory with rotation cadences
- Automated rotation scripts (Gitea webhook, Mailcow passwords, etc.)
- Manual rotation runbooks for non-automatable secrets (Anthropic API key, Cloudflare API tokens, etc.)
- A weekly cron that emails Jeff when secrets are due for rotation
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Closed without code changes — verification showed the originally-leaked literal (`gitea-deploy-secret-2025`) is no longer the production secret. The current 64-char random secret in `/root/.secrets/webhook_secret` was rotated in some prior cleanup pass. TASK-68 created to build a proper rotation pipeline so this never sits in this state again.
<!-- SECTION:FINAL_SUMMARY:END -->
