---
id: TASK-68
title: 'Build secret rotation pipeline (inventory, scripts, weekly digest)'
status: To Do
assignee: []
created_date: '2026-04-27 18:33'
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
- [ ] #1 `dev-ops/security/secrets-inventory.yaml` exists with at least these entries: gitea-webhook-secret, github-webhook-secret, anthropic-api-key, claude-jeffemmett-mailcow, cloudflare-api-token, gitea-api-token
- [ ] #2 `rotate-gitea-webhook.sh` works end-to-end: generates secret, updates all active deploy webhooks via Gitea API, swaps file, restarts container, runs a smoke test push
- [ ] #3 Manual runbook for Anthropic API key rotation lists every consumer file/service and the exact update command
- [ ] #4 `check-rotation-due.sh` runs weekly via systemd timer, emails Jeff with secrets due in next 14 days
- [ ] #5 All scripts are idempotent and can be dry-run with `--dry-run`
- [ ] #6 Inventory `last_rotated` field is updated atomically by the rotation scripts
- [ ] #7 README at `dev-ops/security/README.md` documents the pattern, how to add a new secret, and how to rotate
<!-- AC:END -->
