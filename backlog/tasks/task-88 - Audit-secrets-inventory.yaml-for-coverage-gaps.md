---
id: TASK-88
title: Audit secrets-inventory.yaml for coverage gaps
status: To Do
assignee: []
created_date: '2026-05-14 23:22'
labels:
  - security
  - rotation
  - inventory
  - audit
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The weekly rotation digest (`rotation-digest.timer`, fires Mondays 09:00 UTC) is healthy and active on Netcup — but `dev-ops/security/secrets-inventory.yaml` only tracks 8 secrets. The digest can only remind about secrets it knows exist, so any sensitive value not in the inventory rots silently.

**Known gaps (non-exhaustive, found while doing TASK-86 / TASK-87):**

| Secret | Where it lives | Cadence guess | Status |
|---|---|---|---|
| CrowdSec Traefik LAPI bouncer key | `/root/traefik/config/crowdsec.yml` on Netcup | 180 d | Being rotated under [[task-87]]; add to inventory at same time |
| Vaultwarden ADMIN_TOKEN | `/opt/apps/vaultwarden/.env` (Argon2 hash of passphrase) | 365 d | Untracked |
| Vaultwarden admin passphrase (plaintext) | `~/.secrets/private/vaultwarden_admin_passphrase_jeff.txt` | 365 d | Untracked |
| Uptime Kuma admin password (`KUMA_PASSWORD`) | Infisical → kuma-alert-agent at startup | 365 d | Untracked |
| Uptime Kuma API key | `~/.secrets/private/kuma_api_key` | 365 d | Untracked |
| All Uptime Kuma push tokens | `/etc/uptime-kuma-push.env` on Netcup (HOST_HEALTH, ENGINE_POOL_*, FALKORDB, DB_BACKUP, VAULTWARDEN) | 365 d | Untracked — low impact (per-monitor, single-use), but worth registering for completeness |
| FalkorDB password | `/opt/apps/falkordb/.env` | 180 d | Untracked |
| Infisical client_id/client_secret pairs | one per service in `/opt/apps/*/.env` | 365 d | Untracked (many) |
| `~/.cloudflare-credentials.env` (CLOUDFLARE_API_TOKEN, CLOUDFLARE_TUNNEL_TOKEN, etc.) | local + on server | 180 d | Already partly covered (`cloudflare-api-token` entry) but verify token IDs match what's deployed |
| Various Postgres/MariaDB passwords | per-service `.env` files | 365 d | Untracked |
| `r2_vastai_credentials`, `runpod_api_key`, `vastai_api_key`, `moonshot_api_key`, `erpnext_api_key`, `relos-release.keystore`, `ironclaw_basic_auth_password`, `rmail_*_password`, `forum-replies_p2pfoundation_password`, `directus_fritsch_password`, `commons_hub_*`, `gitea_github_mirror_token`, `gitea_token`, `github_token` | All in `~/.secrets/private/` | varies | Untracked — `ls ~/.secrets/private/` is the canonical starting list |

**Plan:**
1. Walk the canonical sources of secrets: `~/.secrets/private/`, every `/opt/apps/*/.env` on Netcup, every Infisical project, Cloudflare credentials, Mailcow admin, CrowdSec.
2. For each, decide: should it be in `secrets-inventory.yaml`? (If it's a single-use bootstrap token that won't be reused, probably not. If it persists and gates access, yes.)
3. For everything that should be tracked, append an entry. Use existing entries as templates. Set `last_rotated` to the best-known value or, if unknown, `1970-01-01` to force the digest to flag it ASAP.
4. For each new "auto" entry, write a `rotate-<name>.sh`. For "manual" entries, write a `runbook-<name>.md`.
5. Commit + push. Next Monday's digest should fire warnings for everything that hasn't been touched recently.

**Out of scope:** actually performing the rotations. Once inventoried, the digest will queue them naturally.

**Why medium:** no known compromise, but a stale inventory means the existing pipeline is partially blind. Faster to fix once than to discover gaps incident-by-incident.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every sensitive value in ~/.secrets/private/, in /opt/apps/*/.env on Netcup, and in Infisical has either an inventory entry or a documented reason for exclusion (e.g. 'single-use install token')
- [ ] #2 CrowdSec LAPI key inventory entry exists and links to TASK-87 / a rotate-crowdsec-traefik-lapi-key.sh or runbook
- [ ] #3 Vaultwarden ADMIN_TOKEN + plaintext passphrase, Kuma admin password, Kuma API key, FalkorDB password are all inventoried (or explicitly waived in this task's final notes)
- [ ] #4 Running `./security/check-rotation-due.sh --dry-run` (or the manual equivalent) lists no inventory-format errors and matches the entries to consumers correctly
- [ ] #5 Next weekly digest email contains the expected new entries (verify the Monday following the inventory update)
<!-- AC:END -->
