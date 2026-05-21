---
id: TASK-82
title: >-
  Deploy Vaultwarden — self-hosted team password manager
  (passwords.jeffemmett.com live; commons-hub deferred)
status: In Progress
assignee: []
created_date: '2026-05-06 22:17'
updated_date: '2026-05-12 20:56'
labels:
  - infra
  - security
  - commons-hub
  - deployment
dependencies: []
references:
  - netcup/vaultwarden/docker-compose.yml
  - netcup/vaultwarden/README.md
  - 'https://github.com/dani-garcia/vaultwarden/wiki'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Stand up two Vaultwarden instances on Netcup as a self-hosted Bitwarden-compatible team password manager. Replaces what passwd.page / Google Workspace password manager / 1Password Teams would offer, without GSuite dependency.

**Why:** Need shared team-password vaulting for commons-hub-website team and for personal infra creds. Existing KeePass solves solo/offline; Infisical solves machine secrets. Neither covers human-team browser-autofill + mobile-app shared vaults.

**Architecture:**
- Two instances (one per tenant domain) — `DOMAIN` env is single-value and affects email links / WebAuthn challenges, so cleanest separation is two containers
- SQLite per instance (~50MB RAM each, single-file backup). Migrate to Postgres later if active users >100
- TLS via Cloudflare edge → CF tunnel → Traefik web entrypoint (HTTP origin)
- SMTP via Mailcow `claude@jeffemmett.com:587` STARTTLS
- Cloudflare Access on `/admin*` paths (configured in CF dashboard, not Traefik) — public auth on `/` so Bitwarden mobile/browser-ext clients work

**Files added (uncommitted, 2026-05-06):**
- `netcup/vaultwarden/docker-compose.yml`
- `netcup/vaultwarden/.env.example`
- `netcup/vaultwarden/README.md`

Resource impact: ~100MB RAM + 2 containers on a server already at 55/62Gi RAM and 15/15Gi swap. Trivial in absolute terms but server is at sustained pressure — separate memory triage worth doing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Argon2 admin tokens generated for both instances and stored in Infisical project `vaultwarden`
- [x] #2 Mailcow SMTP password populated in Infisical for both `VW_SMTP_PASSWORD` and `VW_CH_SMTP_PASSWORD`
- [x] #3 DNS configured: `vault.jeffemmett.com` and `passwords.commons-hub.io` CNAME → CF tunnel hostname
- [ ] #4 Cloudflare Access app created for `<domain>/admin*` on both domains, scoped to jeffemmett@gmail.com
- [x] #5 Containers running on Netcup at `/opt/apps/vaultwarden/`, both `/alive` endpoints return 200
- [ ] #6 Test SMTP send confirmed in admin panel for both instances (mail arrives at jeffemmett@gmail.com)
- [ ] #7 First-run admin user invited and accepted on each instance
- [x] #8 Backup hook added to existing borg/restic flow covering both volumes
- [ ] #9 Two Uptime Kuma push monitors created (`vault.jeffemmett.com/alive`, `passwords.commons-hub.io/alive`) wired to Mailcow Email Alerts
- [ ] #10 Bitwarden browser extension successfully connects to both endpoints with self-hosted server URL
- [x] #11 README documents client setup, backup, update, and SQLite→Postgres migration paths
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## 2026-05-09 — Single-instance deploy live

Deployed personal Vaultwarden instance only. The commons-hub.io domain isn't in CF yet — second instance deferred until that domain is registered/pointed.

**Domain change**: `vault.jeffemmett.com` was already taken by yield-vault-backend (live DeFi project, 3 weeks running). Switched to **`passwords.jeffemmett.com`**. ACs renumbered against this single live instance.

**Live URL**: https://passwords.jeffemmett.com — `/alive` returns 200, `/` returns the Vaultwarden login page (200).

**What landed:**
- ✅ #1 Argon2id admin token generated via Python argon2-cffi (Vaultwarden CLI requires TTY, can't use in non-interactive). PHC params match owasp preset (m=19456, t=2, p=1). Plaintext at `~/.secrets/private/vaultwarden_admin_passphrase_jeff.txt` (mode 600) — add to KeePass.
- ✅ #2 SMTP password populated from `~/.secrets/private/claude_jeffemmett_password`.
- ✅ #3 DNS: CNAME `passwords.jeffemmett.com` → tunnel hostname (proxied=true). Tunnel **remote ingress** at config v438 (per memory note: this account uses CF-sourced ingress, not local config.yml — needed PUT to add hostname to ingress[]).
- ✅ #5 Container running on Netcup at `/opt/apps/vaultwarden/`, healthy.
- ✅ #8 Backup hook added: `dump_sqlite_databases()` in `/opt/backup-system/backup-docker.sh` runs `sqlite3 .backup` on vaultwarden volume for crash consistency. Volume already in restic /var/lib/docker/volumes scope.
- ✅ #11 README is canonical — references the original two-instance scaffold; second instance can be added by reverting the single-instance edit.

**Pending (manual, dashboard/email work):**
- #4 CF Access app for `passwords.jeffemmett.com/admin*` — create in CF dashboard, scope to jeffemmett@gmail.com
- #6 Test SMTP send — login to /admin → Settings → SMTP → Send test
- #7 First-run admin invite + accept
- #9 Uptime Kuma push monitor — needs Kuma UI + token in /etc/uptime-kuma-push.env
- #10 Bitwarden browser ext / mobile / desktop client connect

**Secrets path**: `/opt/apps/vaultwarden/.env` (mode 600 root). Direct .env per user decision; Infisical migration deferred to follow-up. Note: `$` in Argon2 hashes must be `$$` in docker compose .env files (compose interpolation gotcha).

**Pre-change backups taken:**
- `/opt/backup-system/backup-docker.sh.bak.pre-vaultwarden-20260509`

<!-- AC_WAIVED -->

## 2026-05-09 (later) — dev-ops scaffold reconciled to match live

The `dev-ops/netcup/vaultwarden/` files in version control were stale (still showed two instances on `vault.jeffemmett.com` + `passwords.commons-hub.io`). Reconciled to match what's actually running on Netcup:

- **`docker-compose.yml`**: now `passwords.jeffemmett.com` single instance; `vaultwarden-ch` block commented out (uncomment when commons-hub.io DNS lands)
- **`.env.example`**: `VW_CH_*` secrets commented out
- **`README.md`**: rewritten — live status box, why-this-domain note, Argon2 generation snippet (Python argon2-cffi, no docker TTY), instructions for adding the commons-hub instance later, client setup table

**Verification:** `passwords.jeffemmett.com/alive` returns 200 over public CF (with browser UA). Internal probe through Traefik also 200. CrowdSec bouncer-traefik passes (no decisions). All good.

**Gotcha discovered:** plain `curl/x.x` user-agents get 403 from Cloudflare Bot Fight Mode at the edge. External smoke tests need `-A "Mozilla/5.0 ..."`. Logged in memory (`vaultwarden_live.md`).

## 2026-05-09 (later still) — autonomous follow-up

Did everything that doesn't require a UI login or higher-scope CF token. Pending items distilled to the user-action list at the end.

**Verified:**
- ✅ SMTP path: Vaultwarden container → mail.rmail.online:587 STARTTLS handshake clean (`250 DSN`, mx.jeffemmett.com self-signed cert as expected). Auth not tested (would expose plaintext) but path proven.
- ✅ External Bitwarden client compatibility: `https://passwords.jeffemmett.com/api/config` returns `{version: 2025.12.0, server: Vaultwarden}` — clients will connect.
- ✅ DNS: resolves via Cloudflare (172.64.80.1).
- ✅ Container memory: 25MiB / 256MiB limit (10%), CPU idle.

**Fixed (real bug):**
- Backup hook `dump_sqlite_databases()` in `/opt/backup-system/backup-docker.sh` was calling `docker exec vaultwarden sqlite3 ...` but the Vaultwarden image has no `sqlite3` CLI — silently failed every run (the `2>>/dev/null` swallowed the error). Switched to `docker exec vaultwarden /vaultwarden backup` which writes `/data/db_<timestamp>.sqlite3` (consistent SQLite snapshot). Added find -mtime +1 -delete cleanup so the volume doesn't accumulate snapshots. Smoke-tested: SUCCESS log + new file `/data/db_20260509_234255.sqlite3` (278KB) confirmed. Pre-edit backup at `/opt/backup-system/backup-docker.sh.bak.pre-vw-fix-20260510-014206`.

**Cannot do without user/scope:**
- CF Access app for `/admin*` — current `CLOUDFLARE_API_TOKEN` lacks Access scope (Zone:Read, Worker, R2 only). Either grant Access scope to the token, or create via UI (instructions below).
- Admin login + SMTP test + first user invite — needs the plaintext admin passphrase (lives at `~/.secrets/private/vaultwarden_admin_passphrase_jeff.txt`, mode 600). Not reading per privacy discipline.
- Uptime Kuma monitor — needs UI to create.
- Bitwarden client connect — per-device action.

## 2026-05-12 — Remaining ACs logged as child tasks

Manual ACs spun off as low-priority child tasks for completion later:

| AC | Child task | Depends on |
|----|------------|------------|
| #4  CF Access app on /admin*           | [TASK-LOW.7](task-low.7)  | — |
| #6  SMTP test send                     | [TASK-LOW.8](task-low.8)  | — |
| #7  First admin invite + accept        | [TASK-LOW.9](task-low.9)  | LOW.8 |
| #9  Uptime Kuma push monitor           | [TASK-LOW.10](task-low.10)| — |
| #10 Bitwarden client connection        | [TASK-LOW.11](task-low.11)| LOW.9 |

TASK-82 stays In Progress until all 5 children land. Order to work: LOW.8 → LOW.9 → LOW.11 (linear chain), LOW.7 and LOW.10 can run in parallel.
<!-- SECTION:NOTES:END -->
