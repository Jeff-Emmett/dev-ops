---
id: TASK-89
title: 'Key-rotation pipeline: remaining coverage + hardening (post-TASK-88)'
status: In Progress
assignee: []
created_date: '2026-05-15 23:19'
updated_date: '2026-05-15 23:45'
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
- [x] #1 Backup-file retention policy defined + enforced (cron/timer) for ~/.secrets/private/ and Netcup .bak-* rotation artifacts
- [x] #2 The 4 Docker-secret listmonk tenants inventoried with a working secret-file rotation method (or explicitly waived with rationale)
- [x] #3 cyclos/mattermost/affine: profiles written + flipped to auto when their stacks next run (or runbook if split-config) — or a note recording they remain stopped
- [ ] #4 The post-2026-05-18 OVERDUE digest set burned down to zero (rotated or backdated-with-evidence)
- [x] #5 No inventory entry points at a runbook file that doesn't exist AND is due within 30 days (write-on-first-rotation is fine for not-yet-due entries)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
AC #5 closed 2026-05-15/16 (stub-runbook batches 1+2). All 59 inventory entries now resolve to an existing runbook or script — 0 missing (was 35).

Approach: consolidation over redundancy (per project style guide — no 35 near-identical files). 10 new runbooks:
- Shared patterns: mailcow-mailbox (3 entries), directus-admin (3), multi-secret-env (7+affine), multi-tenant-secrets (3), infisical-service-token (2), audit-meta (2 — these are review-cadence not rotations), kuma (2)
- Bespoke: gitea-github-mirror-token (~50-repo fanout, DB-path per gitea_webhook_patch_bug), github-webhook-secret (per-repo gh PATCH; manual sibling of the automated gitea one), vaultwarden-admin-token (live=script, documents deferred commons-hub)
- Repoints to existing runbooks: external-api-key (erpnext, r2-vastai), cloudflare-tokens-bundle (cloudflare-api-token), listmonk-postgres (cyclos/mattermost/rnotes — split-config postgres pattern), TEMPLATE (3 generic service pws)

Modes now: 9 auto / 50 manual across 59 entries. Remaining TASK-89 ACs (#1 backup retention, #2 listmonk Docker-secret tenants, #3 stopped-service profiles, #4 burn down Monday OVERDUE) are independent of the runbook gap and stay open.

AC #1/#2/#3 closed 2026-05-16 (commit c72ca91):

**#1** prune-rotation-backups.sh + .service + .timer. Monthly local user timer installed & enabled (next 2026-06-01 04:00), --apply enforces. Policy: keep newest 2 backups/stem unconditionally, delete older past RETAIN_DAYS=90. Covers local ~/.secrets/private + Netcup (/root/.secrets, /root/traefik[/config], /opt/syncthing/config, *.bak-pre-rotate-* under /opt). Dry-run verified safe (0 at 90d; RETAIN_DAYS=0 test selects correctly).

**#2** New inventory entry `listmonk-tenant-postgres` (multi-file: the 4 Docker-secret tenants p2p/worldplay/crypto-commons/commons-hub /opt/apps/*-listmonk/db_password). Method documented = runbook-listmonk-postgres.md + the Docker-secret delta (rotate ./db_password source file, staggered per tenant). Inventory now 60 entries.

**#3** cyclos/mattermost/affine entries carry explicit STACK-STOPPED notes with the same-${VAR} recheck instruction for when they next run.

**#4 remains the only open AC** — inherently post-2026-05-18: burn down the OVERDUE set the Monday digest produces. Cannot be closed before the digest fires. Everything is staged so it's a quick burn-down then (run script / follow runbook / mark-rotated --backdate-with-evidence per entry).

TASK-89 stays In Progress on AC #4 alone (AC gate; #4 is genuinely time-gated, not skipped).
<!-- SECTION:NOTES:END -->
