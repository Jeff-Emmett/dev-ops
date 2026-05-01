---
id: TASK-68
title: 'Build secret rotation pipeline (inventory, scripts, weekly digest)'
status: Done
assignee: []
created_date: '2026-04-27 18:33'
updated_date: '2026-05-01 21:28'
labels:
  - security
  - infra
  - automation
dependencies: []
references:
  - 'task-53 (closed: leaked secret already mitigated, rotation tooling missing)'
  - /opt/deploy-webhook/webhook.py
  - /root/.secrets/ on Netcup
  - infisical/scripts/audit-secrets.sh
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replaces ad-hoc secret rotation (see TASK-53) with a maintained pipeline so secrets are rotated on a regular cadence and we know what depends on what.

**Components:**

1. **Inventory** (`dev-ops/security/secrets-inventory.yaml`) — a registry with one entry per rotatable secret:
   - `name`, `description`, `category` (webhook | api-key | password | cert)
   - `location` (file path on Netcup, Infisical project/path, or external — e.g. \"Anthropic console\")
   - `consumers` (services/files/repos that need to be updated when this rotates)
   - `rotation` (`auto` with script ref, or `manual` with runbook ref)
   - `cadence_days` (e.g. 90, 180, 365)
   - `last_rotated` (date)

2. **Automated rotation scripts** (`dev-ops/security/rotate-*.sh`) — initial set:
   - `rotate-gitea-webhook.sh` — generates 64-char secret, PATCHes all `deploy.jeffemmett.com` webhooks via Gitea API, writes new file, restarts deploy-webhook, smoke tests with one push
   - `rotate-claude-jeffemmett-imap.sh` — Mailcow IMAP/SMTP password for `claude@jeffemmett.com`
   - (more added incrementally as needed)

3. **Manual rotation runbooks** (`dev-ops/security/runbook-*.md`) — for secrets that need human steps:
   - Anthropic API key (console-only, must be done by hand; runbook lists every consumer to update)
   - Cloudflare API token
   - Porkbun API key
   - GitHub PAT
   - Gitea API token

4. **Weekly digest** — systemd timer on Netcup that runs `check-rotation-due.sh`, computes which secrets are within 14 days of due, emails Jeff via the same Mailcow/sendmail path used for backlog notifications.

**Why high priority:** the gap exposed by TASK-53 was that even after a leak, nobody had a system to identify what the consumers were or to roll the secret. We have ~100+ Gitea webhooks sharing one secret, an Anthropic key in active use, multiple service passwords — we need a single source of truth for \"when does this rot\".
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `dev-ops/security/secrets-inventory.yaml` exists with at least these entries: gitea-webhook-secret, github-webhook-secret, anthropic-api-key, claude-jeffemmett-mailcow, cloudflare-api-token, gitea-api-token
- [x] #2 `rotate-gitea-webhook.sh` works end-to-end: generates secret, updates all active deploy webhooks via Gitea API, swaps file, restarts container, runs a smoke test push
- [x] #3 Manual runbook for Anthropic API key rotation lists every consumer file/service and the exact update command
- [x] #4 `check-rotation-due.sh` runs weekly via systemd timer, emails Jeff with secrets due in next 14 days
- [x] #5 All scripts are idempotent and can be dry-run with `--dry-run`
- [x] #6 Inventory `last_rotated` field is updated atomically by the rotation scripts
- [x] #7 README at `dev-ops/security/README.md` documents the pattern, how to add a new secret, and how to rotate
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**2026-04-27 — Pipeline scaffolded and live.**

Files in `dev-ops/security/`:
- `secrets-inventory.yaml` — 7 entries (gitea-webhook, github-webhook, anthropic-api-key, claude-jeffemmett-mailcow, cloudflare-api-token, gitea-api-token, porkbun-api-key)
- `_lib.sh` — shared helpers (inventory_get, inventory_mark_rotated, parse_common_args, dry-run support)
- `mark-rotated.sh` — bump last_rotated post-manual-rotation
- `rotate-gitea-webhook.sh` — full automation w/ dry-run; tested in dry-run mode against live Gitea DB, found 125 webhooks correctly
- `runbook-anthropic-api-key.md` — manual rotation steps + rollback for the 6 .env consumer files identified by grep
- `check-rotation-due.sh` — weekly digest, tested end-to-end on Netcup (real email sent: 'digest sent: [secrets] 7 secret(s) need rotation attention')
- `rotation-digest.service` + `.timer` — installed on Netcup, enabled, first scheduled fire 2026-05-04 11:00 CEST

Deployed: dev → main → Gitea push (commit `f2a857f`) → git pull on Netcup `/opt/dev-ops/` → `systemctl enable --now rotation-digest.timer`.

AC#2 left unchecked: the gitea webhook rotation script has been validated in dry-run only. AC#2 will be checked the first time a real rotation is run successfully (smoke test: empty 'Invalid signature' count in deploy-webhook logs after rotation).

**2026-05-01 — AC#2 closed; rotation script overhauled.**

Live rotation attempt revealed Gitea 1.21's `PATCH /api/v1/repos/:o/:r/hooks/:id` silently ignores `config.secret` updates: API returns 200, `updated_at` bumps, but DB column is never touched. Script's PATCH-loop was a 38-second no-op. File got rewritten to a fresh openssl-rand secret while gitea webhooks still held the original — 1 signature rejection from the smoke test. State recovered by reading the still-original DB secret back into the file (no actual rotation done at that point).

Fix: rewrote `rotate-gitea-webhook.sh` to use direct `UPDATE webhook SET secret = ... WHERE url LIKE '%deploy.jeffemmett.com%'` against gitea-db inside the same SSH session as the file swap. Also fixed the `bak.$(date...)` heredoc bug (literal `$(date)` in filename when the script tried escape-quoting through nested ssh strings).

Live rotation re-run cleanly:
  - `UPDATE 125` (all matching webhooks in one transaction)
  - host `/root/.secrets/webhook_secret` md5 = container `/run/secrets/webhook_secret` md5 = all 125 webhook DB md5 = `c30165583166bb5d…`
  - smoke test passed (no `Invalid signature` in deploy-webhook logs)
  - 5 follow-up `/tests` triggers all returned 204 with zero rejections
  - `last_rotated` = 2026-05-01
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Secret rotation pipeline shipped: inventory + auto/manual scripts + weekly Mailcow digest, all 7 ACs satisfied. The first live rotation found Gitea 1.21's API silently drops webhook secret PATCHes; pivoted to direct gitea-db UPDATE which is now the script's primary path. Pipeline self-validated end-to-end: 125 webhooks rotated in one transaction, host file + container mount + DB rows all aligned, no signature rejections in deploy-webhook logs post-rotation.
<!-- SECTION:FINAL_SUMMARY:END -->
