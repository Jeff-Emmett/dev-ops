---
id: TASK-88
title: Audit secrets-inventory.yaml for coverage gaps
status: In Progress
assignee: []
created_date: '2026-05-14 23:22'
updated_date: '2026-05-15 00:17'
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
- [x] #3 Vaultwarden ADMIN_TOKEN + plaintext passphrase, Kuma admin password, Kuma API key, FalkorDB password are all inventoried (or explicitly waived in this task's final notes)
- [ ] #4 Running `./security/check-rotation-due.sh --dry-run` (or the manual equivalent) lists no inventory-format errors and matches the entries to consumers correctly
- [ ] #5 Next weekly digest email contains the expected new entries (verify the Monday following the inventory update)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Phased sweep plan

Each phase is independent — stop at any point and the digest gets stricter for what's already in.

### Phase 0 — Discover (1 hr)
- `ls ~/.secrets/private/` — every file is a candidate
- `find /opt/apps -maxdepth 3 -name .env` on Netcup — every service's env
- List Infisical projects (`infisical projects list` or via web UI) — every secret per project
- Audit `~/.cloudflare-credentials.env`, KeePass vault headers (just titles), and Mailcow admin / database password
- Produce a working CSV: secret-name | location | consumers (best guess) | suggested cadence | rotation difficulty (auto/manual)

### Phase 1 — Easy wins (this turn)
Persistent gate-secrets where a single inventory entry buys real coverage. Five obvious adds:
1. **vaultwarden-admin-token** — manual; `/opt/apps/vaultwarden/.env` (Argon2) + `~/.secrets/private/vaultwarden_admin_passphrase_jeff.txt` (plaintext); cadence 365d
2. **kuma-admin-password** — manual; Infisical (kuma-alert-agent project); cadence 365d
3. **kuma-api-key** — manual; `~/.secrets/private/kuma_api_key`; cadence 365d
4. **falkordb-password** — auto candidate; `/opt/apps/falkordb/.env`; cadence 180d
5. **vw-smtp-password** — already covered indirectly via `claude-jeffemmett-mailcow` (same value); add cross-reference note rather than a new entry

### Phase 2 — ~/.secrets/private/ walk (1-2 hr)
30 files in there per `ls` earlier. For each:
- If still in use → inventory with best-known `last_rotated`
- If obsolete → mark in a `WAIVED.md` adjacent to the inventory with rationale
- Specific ones expected to make the cut: `runpod_api_key`, `vastai_api_key`, `moonshot_api_key`, `erpnext_api_key`, `r2_vastai_credentials`, `gitea_github_mirror_token`, `gitea_token`, `github_token`, `infisical_funion_sidecar_client_secret`, `relos-release.keystore`, `ironclaw_basic_auth_password`, `rmail_team_password`, `rmail_noreply_password`, `forum-replies_p2pfoundation_password`, `directus_fritsch_password`, `commons_hub_admin_password`, `commons_hub_directus_password`, `syncthing_*_api_key`, `vaultwarden_admin_passphrase_commons-hub.txt` (deferred VW instance)

### Phase 3 — Netcup per-service .env sweep (2-3 hr)
For each `/opt/apps/<svc>/.env` and `/opt/services/<svc>/.env`, identify the values that aren't Infisical client_id/secret (those are bootstrap, ~waivable):
- Postgres / MariaDB passwords for stateful services
- Service-specific API tokens (Directus, ERPNext, Listmonk, n8n, Outline, Postiz, RSocials Postgres, etc.)
- Decide per-service whether master rotation is feasible

### Phase 4 — Infisical project audit (1-2 hr)
- `infisical secrets list --projectSlug=<each>` for every project
- Cross-reference against inventory; everything in Infisical that gates real access → inventory entry pointing to the Infisical project/path
- Infisical client_id/secret pairs themselves are bootstrap creds — they should be in inventory with a separate "rotate via Infisical service-token UI" runbook

### Phase 5 — Verify digest fires correctly
- Run `./security/check-rotation-due.sh --dry-run` (or eyeball the script's logic against the inventory)
- Force a "due now" entry temporarily; confirm the email digest contains it
- Watch next Monday's actual digest for unexpected gaps

### Conventions to keep
- `last_rotated: 1970-01-01` = "never rotated, flag immediately" (forces next-Monday digest)
- Entry without a rotation script = `mode: manual` + a runbook (even if the runbook is just a stub for the first version)
- Secrets whose rotation involves downtime get a `notes:` line spelling out the blast radius
- Secrets that live in multiple places (e.g. plaintext + hash) get a single `name` with `location.type: multi-file` and all paths listed, like `engine-pool-auth-token` already does
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Phase 1 complete 2026-05-14:

**Added to inventory** (all gate-secrets):
- `vaultwarden-admin-token` (multi-file plaintext + Argon2)
- `kuma-admin-password` (Infisical-backed)
- `kuma-api-key`
- `falkordb-password`

Verified `/opt/dev-ops/security/secrets-inventory.yaml` shows 13 entries after `git pull origin main` on Netcup as root (sudo -u deploy needed gitea SSH keys it doesn't have).

**Side effect:** `check-rotation-due.sh` has no --dry-run flag and always sends. Triggering it for verification fired an actual digest email at 2026-05-14 ~18:04 CEST. Subject `'[secrets] 13 secret(s) need rotation attention'` was misleading — only the two `1970-01-01` kuma entries are genuinely overdue; the count picked up the 'All other secrets' section. Fixed `check-rotation-due.sh` to count only OVERDUE + 'Due within Nd' sections; next Monday's digest will be accurate.

**Phase 1 AC #3 (this task): ✓ done.**

Next phases (per plan): ~/.secrets/private/ walk (Phase 2), /opt/apps/*/.env sweep (Phase 3), Infisical audit (Phase 4). Stop point reasonable.

Phase 2 complete 2026-05-14:

**~/.secrets/private/ walked (31 files).**

- **21 new inventory entries** added (TASK-88 Phase 2 block in secrets-inventory.yaml). cadence_days default 180d for service passwords, 90d for paid LLM APIs (moonshot), 365d for things that genuinely don't rotate often (Syncthing, mirror PATs, Infisical service tokens).
- **1 existing entry updated** to multi-file: `gitea-api-token` now covers both Netcup + local copies.
- **3 already covered** in earlier phases: claude_jeffemmett_password, kuma_api_key, vaultwarden_admin_passphrase_jeff.txt.
- **6 waived** with rationale in `security/WAIVED.md`:
  - `netcup_ip` (IP, not a secret)
  - `syncthing_netcup_device_id` (public peer ID, not a credential)
  - `claude_jeffemmett_password.bak-20260421-1140` (stale backup)
  - `rspace-env-secrets-2026-05-05.txt` (dated snapshot of a rotation)
  - `rspace-rapp-keys-2026-05-05` (same)
  - `relos-release.keystore` (Android release-signing key — rotating breaks installed-app upgrade path; once-per-incident only)

**Inventory total now 34 entries** (was 13 at start of TASK-88).

**Forcing-flag entries** (last_rotated=1970-01-01) so next Monday's digest will surface them: kuma-admin-password, kuma-api-key, erpnext-api-key. 

**Stubs needed** (~20 runbook-*.md files referenced but not yet written). Each is a 10-line write-it-when-first-rotated runbook. Not blocking; the digest can flag and a human follow.

AC #1 progress: ~/.secrets/private/ side covered (inventory or WAIVED for every file). Still pending: /opt/apps/*/.env on Netcup (Phase 3), Infisical projects (Phase 4).
<!-- SECTION:NOTES:END -->
