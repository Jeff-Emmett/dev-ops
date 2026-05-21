---
id: TASK-CRITICAL.1
title: Rotate exposed API keys from Obsidian vault git history
status: To Do
assignee: []
created_date: '2026-03-13 05:22'
updated_date: '2026-04-26 23:29'
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

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Anthropic key #1 (sk-ant...0ndS) revoked at console.anthropic.com
- [ ] #2 Anthropic key #2 (sk-ant...E5Nb) revoked at console.anthropic.com
- [ ] #3 OpenAI key (sk-JI2pfIt...) revoked at platform.openai.com
- [ ] #4 OpenAI key (sk-pJI2pfIt...) revoked at platform.openai.com
- [ ] #5 Old OpenAI key (sk-dn6L...) revoked
- [ ] #6 OpenRouter key (sk-or-v1-1dde7e...) revoked at openrouter.ai
- [ ] #7 GitHub PAT (ghp_32TGpISP...) revoked at github.com/settings/tokens
- [ ] #8 Cloudflare API token (nOFgqtRyzbb...) revoked at dash.cloudflare.com
- [ ] #9 Cloudflare API token (oIudJ9v3tjh...) revoked at dash.cloudflare.com
- [ ] #10 R2 access key (e6ff6811...) + secret (0e833449...) rotated in Cloudflare R2
- [ ] #11 R2 token (IoRwxTeGOnz...) rotated
- [ ] #12 Cloudflare Calls token (909512760d89...) + APP_SECRET rotated
- [ ] #13 Daily.co API key (644a959db82...) rotated at daily.co
- [ ] #14 Google Maps API key (AIzaSyC2oo...) rotated at console.cloud.google.com (with referrer restriction)
- [ ] #15 HuggingFace token (hf_dYGfMLJg...) rotated at huggingface.co/settings/tokens
- [ ] #16 Stripe live secret (ocyn-strr-...) rotated at dashboard.stripe.com
- [ ] #17 Stripe test secret (sk_test_51CYkie...) rotated at dashboard.stripe.com
- [ ] #18 Duffel test key (duffel_test_-PDU...) rotated at duffel.com
- [ ] #19 Amadeus key + secret (EqCDJyk7..., ANejA71...) rotated at developers.amadeus.com
- [ ] #20 SERP API key (34696f07...) rotated at serpapi.com
- [ ] #21 Deepgram key (4993e972...) rotated at console.deepgram.com
- [ ] #22 Fathom key + webhook secret rotated at app.usefathom.com
- [ ] #23 Fal Drawfast key (47c5f91d...:d62a0f97...) rotated at fal.ai
- [ ] #24 Obsidian Local REST API key regenerated in Obsidian plugin settings
- [ ] #25 Each rotated key stored in Infisical (and old removed from KeePass if present)
- [ ] #26 Force-push scrubbed history to Gitea for both vaults
- [ ] #27 Verify GitHub mirror clean (or force-push there if mirrored)
- [ ] #28 Run git gc --prune=now on server-side Gitea repos
<!-- AC:END -->

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

## 2026-04-26 — History scrub completed locally

**Scrubbed in working tree (committed):**
- Jeff's Vault: Anthropic key.md, Cloudflare API Calls.md, .smart-env/smart_env.json, all .obsidian/plugins/{whisper,copilot,obsidian-textgenerator-plugin,obsidian-local-rest-api}/data.json, deleted .smart-env/{multi,smart_threads}/* test artifacts
- obsidian-vault-merged: Cloudflare API Calls.md (only file with secrets)

**Git history rewritten via `git filter-repo --replace-text`:**
- Backups: ~/.secrets/vault-backups/{jeffs-vault,obsidian-merged}-pre-scrub-20260426-*.bundle (299M, 322M)
- Verified: `git log --all -p | grep` finds zero real secrets in either repo

**Additional secrets found and redacted (not in original task list):**
- 2 R2 keys (access + secret) + R2 token
- OpenRouter key (sk-or-v1-1dde7e...)
- HuggingFace (hf_dYGfMLJg...)
- Stripe live secret (ocyn-strr-...) — TASK had test as expired but live was still in history
- Cloudflare Calls token (909512760d89...)
- Daily.co API key
- Fathom key + webhook secret
- Fal Drawfast key
- Obsidian Local REST API key
- Old OpenAI key (sk-dn6L...)
- Stale GitHub PAT (github_pat_11ALG... — was marked expired)

**Pending (NOT yet done):**
- [ ] Force-push Jeff's Vault → gitea (origin removed by filter-repo, must re-add)
- [ ] Force-push obsidian-vault-merged → gitea
- [ ] Confirm GitHub mirror status for both repos and force-push there if mirrored
- [ ] `git gc --prune=now --aggressive` on Gitea server-side repos
- [ ] User to rotate every still-active key in Anthropic/OpenAI/OpenRouter/HF/Stripe/Cloudflare/Cloudflare-Calls/Daily/Google-Maps/Duffel/Amadeus/SERP/Fathom/Deepgram/Fal/Obsidian-REST consoles
<!-- SECTION:NOTES:END -->
