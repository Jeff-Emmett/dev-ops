---
id: TASK-89
title: 'Key-rotation pipeline: remaining coverage + hardening (post-TASK-88)'
status: To Do
assignee: []
created_date: '2026-05-15 23:19'
labels:
  - security
  - rotation
  - followup
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Forward-looking work after TASK-86/87/88 built the rotation pipeline (59 inventory entries, 9 auto scripts — 4 proven live, weekly digest accurate). This task tracks what's deliberately deferred so it isn't lost.

## 1. Stub runbooks (35 entries)
35 inventory entries have a `runbook:` pointer to a file that doesn't exist yet (all referenced scripts DO exist). These are intentionally "write-on-first-rotation" — the weekly digest surfaces which are due first, so write the runbook when you actually rotate that secret. Priority order = whatever the Monday digest flags as OVERDUE.

Highest-value to write proactively (high blast radius, no shared pattern):
- `runbook-cloudflare-api-token.md` (overlaps the already-written runbook-cloudflare-tokens-bundle.md — may just cross-reference)
- `runbook-claude-jeffemmett-mailcow.md` (referenced by mailcow-smtp-stash runbook already)
- `runbook-gitea-github-mirror-token.md` (~50 mirrored repos — high fanout)
- `runbook-rspace-online-secrets.md`, `runbook-payment-infra-secrets.md`, `runbook-pentagi-secrets.md` (big multi-secret .envs)
- `runbook-twenty-multi-tenant-secrets.md`, `runbook-postiz-multi-tenant-secrets.md` (multi-tenant)

The rest can lean on `runbook-external-api-key.md` / `runbook-TEMPLATE.md` patterns.

## 2. Postgres profiles for currently-stopped services
cyclos / mattermost / affine are inventoried `mode: manual` because their compose stacks are stopped (can't ALTER USER on a down DB). When any is brought back up:
- Verify the app + postgres derive the DB password from the SAME `${VAR}` (the listmonk-incident check — see memory `postgres_rotation_consumer_verification`).
- If same-var: add a `security/postgres-profiles/<svc>.sh` (copy n8n.sh, set CONSUMER_CONTAINER), flip the inventory entry to `mode: auto`.
- If split-config (like listmonk): write a bespoke lockstep runbook, keep `mode: manual`.

## 3. The 4 listmonk tenant instances (not yet inventoried)
p2p-listmonk / worldplay-listmonk / crypto-commons-listmonk / commons-hub-listmonk use Docker-secret passwords (`POSTGRES_PASSWORD_FILE=/run/secrets/db_password`), NOT env vars. They need: inventory entries + a secret-file rotation variant (rotate the Docker secret file + ALTER USER + restart both db+app + the same config.toml lockstep listmonk needs). Distinct from rotate-postgres-password.sh's env-var model.

## 4. Backup-file hygiene
This session's live rotations + future ones leave `.bak-pre-rotate-*` / `.bak-stale-*` files in `~/.secrets/private/` and on Netcup (`/root/.secrets/`, `/opt/.../`). Define a retention policy (e.g. keep 2 most recent per secret, prune >90d) and a small cron/systemd-timer to enforce it. Avoid unbounded stale-credential sprawl.

## 5. Operational: work down the OVERDUE set
The Monday 2026-05-18 digest will flag ~26 OVERDUE entries (mostly `last_rotated: 1970-01-01` forced-flags + moonshot). For each: either actually rotate (run the script / follow the runbook) OR, if the current value is known-good and was set at a known date, backdate `last_rotated` via `./security/mark-rotated.sh <name>` + commit. Burn the list down so the digest signal stays meaningful.

## Out of scope (tracked elsewhere)
- TASK-88 AC #5 (verify the Monday digest fires correctly) stays on TASK-88.
- The configuration-repo dev/main divergence (statusline work) is a separate non-rotation concern.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Backup-file retention policy defined + enforced (cron/timer) for ~/.secrets/private/ and Netcup .bak-* rotation artifacts
- [ ] #2 The 4 Docker-secret listmonk tenants inventoried with a working secret-file rotation method (or explicitly waived with rationale)
- [ ] #3 cyclos/mattermost/affine: profiles written + flipped to auto when their stacks next run (or runbook if split-config) — or a note recording they remain stopped
- [ ] #4 The post-2026-05-18 OVERDUE digest set burned down to zero (rotated or backdated-with-evidence)
- [ ] #5 No inventory entry points at a runbook file that doesn't exist AND is due within 30 days (write-on-first-rotation is fine for not-yet-due entries)
<!-- AC:END -->
