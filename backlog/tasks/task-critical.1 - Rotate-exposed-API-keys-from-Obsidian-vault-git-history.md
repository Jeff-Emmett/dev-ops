---
id: TASK-CRITICAL.1
title: Rotate exposed API keys from Obsidian vault git history
status: To Do
assignee: []
created_date: '2026-03-13 05:22'
updated_date: '2026-03-24 17:18'
labels: []
dependencies: []
parent_task_id: TASK-CRITICAL
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
obsidian-vault-merged repo (Gitea-only, private) has real API keys in git history (commit a27f88d). Files were deleted in 814ee3f but secrets remain in history. 10 of 13 keys are STILL ACTIVE and must be rotated immediately.

CRITICAL (rotate first):
- [ ] Anthropic API key #1 (sk-ant-api03-0ndS...) — from Anthropic key.md
- [ ] Anthropic API key #2 (sk-ant-api03-E5Nb...) — from Cloudflare API Calls.md
- [ ] GitHub PAT (ghp_lB3e...) — from Quartz-live Github token.md
- [ ] GitHub PAT (ghp_32TG...) — from Obsidian Git Backup.md

HIGH (rotate next):
- [ ] Deepgram API key (4993e972...) — from Cloudflare API Calls.md
- [ ] Daily API key (644a959d...) — from Cloudflare API Calls.md
- [ ] Google Maps API key (AIzaSyC2...) — from Cloudflare API Calls.md

MEDIUM (rotate after):
- [ ] Duffel test token (duffel_test_-PDU...) — from Cloudflare API Calls.md
- [ ] Amadeus API key + secret — from Cloudflare API Calls.md
- [ ] SERP API key (34696f07...) — from Cloudflare API Calls.md

Already expired (no action needed):
- GitHub PAT (github_pat_11ALG...) — 401
- Cloudflare API token — 401
- Stripe test key — 401

After rotation:
- [ ] Scrub git history with git-filter-repo (remove 6 secret-containing files)
- [ ] Force-push to Gitea
- [ ] Run git gc --prune=now on Gitea server repo
- [ ] Update any services using rotated keys
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Key Status Audit (2026-03-15)

### STILL ACTIVE (verified via API):
- Anthropic key #1 (sk-ant...0ndS) — HTTP 200
- Anthropic key #2 (sk-ant...E5Nb) — HTTP 200
- GitHub PAT (ghp_lB3e...) — HTTP 200
- GitHub PAT (ghp_32TG...) — HTTP 200
- Deepgram — HTTP 200
- Daily.co — HTTP 200
- Google Maps — HTTP 200
- Duffel test — HTTP 200
- Amadeus — HTTP 200
- SERP API — HTTP 200

### EXPIRED (no action needed):
- GitHub PAT (github_pat_11ALG...) — 401
- Cloudflare API token — 401
- Stripe test key — 401

### Infisical/KeePass coverage:
- Anthropic: Individual projects have ANTHROPIC_API_KEY but unclear if these specific keys
- GitHub: claude-ops /git has GITHUB_TOKEN but may be different key
- Daily.co: Partial (canvas-website worker binding)
- Deepgram, Google Maps, Duffel, Amadeus, SERP, Pusher, Supabase: NOT in Infisical

### Active usage found in repos:
- Pusher + Supabase → betting-prediction-app (env.local)
- Amadeus → flights-search
- Daily.co → canvas-website (worker)
- Google Maps → canvas-website (embed maps)
- Deepgram, Duffel, SERP, Cloudflare Calls → no active usage

### Before rotating: Save keys that aren't elsewhere to Infisical/KeePass first!

## Git History Scrub Complete (2026-03-15)
- 7 secret-containing files removed from all commits via git-filter-branch
- Files removed: Anthropic key.md, Cloudflare API Calls.md, MCP Server Setup.md, Obsidian Git Backup.md, Quartz-live Github token.md, Betting App APIs.md, 2025-08-08.md
- Gitea bare repo updated directly + git gc --prune=now
- Local repo scrubbed with git-filter-repo
- Verified: `git show main:"Anthropic key.md"` → "path does not exist"
- All vault repos confirmed PRIVATE (Gitea 404, GitHub private/not-found)

Remaining: Rotate 10 active keys on provider dashboards

## Daily.co + Google Maps Removed (2026-03-23)
- Daily.co: all config, env vars, worker types, Dockerfile args removed from canvas-website
- Google Maps: embed logic replaced with OpenStreetMap (auto-converts Google Maps URLs to OSM)
- No API keys needed for OSM
- Commit: 5883228 on canvas-website dev branch
- These keys no longer need rotation — just revoke on dashboards:
  - Daily.co: https://dashboard.daily.co/
  - Google Maps: https://console.cloud.google.com/apis/credentials
- daily-examples repo can be archived (reference only, no longer used)

## Rotation Complete (2026-03-24)

DONE:
- Anthropic keys rotated — 1 new consolidated key, 5 old keys deleted
- GitHub PATs rotated — 1 new fine-grained PAT, 3 old classic PATs deleted
- gh CLI + ~/.git-credentials rewired to new PAT via Infisical
- Daily.co key revoked (removed from codebase, replaced with Jitsi)
- Google Maps key deleted (replaced with OpenStreetMap)
- Google Cloud service account key deleted
- Deepgram key revoked
- Git history scrubbed (7 files removed from all commits)
- Gitea bare repo updated + GC'd

REMAINING (low priority, no active services):
- Amadeus — rotate or delete
- SERP API — delete
- Duffel — delete test token
<!-- SECTION:NOTES:END -->
