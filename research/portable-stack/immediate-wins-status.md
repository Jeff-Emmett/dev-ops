# Immediate Wins Status — 2026-05-09 (FINAL)

## ✅ Completed in this session

### 1. CF DNS TTL drop — 37/37 records to 300s

- **Scan**: 94 zones, only 37 records had TTL > 300 (rest already on `auto`/`ttl: 1`).
- **Targeted**: 8 MX, 26 TXT (DKIM/DMARC/SPF), 3 CNAME (autoconfig/autodiscover).
- **Action**: PATCH each to TTL=300 via `CLOUDFLARE_INFRA_TOKEN`.
- **Outcome**: 37 OK / 0 failed. Phase B cutover prep complete.
- Scan script: `cf-ttl-scan.sh` (this dir, on Netcup at `/tmp/cf-ttl-scan.sh`).

### 2. CF Access inventory — 32 apps, 39 policies

- **Source-of-truth export** for Phase A Authentik migration mapping.
- Files in `cf-access-inventory/`:
  - `apps-raw.json` — raw CF API
  - `access-policies-raw.txt` — per-app policy dump
  - `access-inventory.json` — structured inventory
  - `access-inventory.md` — Authentik mapping table (3 bypass + 29 allow-listed)
- Each row maps to one Authentik Application + Provider + Policy.

### 3. CrowdSec deployed end-to-end (LAPI + bouncer)

- **CrowdSec daemon** at `/opt/apps/crowdsec/`:
  - Image: `crowdsecurity/crowdsec:v1.6.4`
  - LAPI on `127.0.0.1:6060`
  - Collections: linux, sshd, iptables, http-cve, base-http-scenarios, whitelist-good-actors
  - Datasource: journalctl (sshd via systemd unit)
- **Traefik forward-auth bouncer** (`fbonalair/traefik-crowdsec-bouncer:0.5.0`):
  - Container `bouncer-traefik`, joined to both `crowdsec-internal` and `traefik-public` networks
  - API key generated via `cscli bouncers add traefik-bouncer`
  - Middleware `crowdsec@file` defined in `/root/traefik/config/crowdsec.yml`
  - Wired into both Traefik entrypoints (`web` + `websecure`) chained before `security-headers`
  - **Verified live**: ~1-3ms forwardAuth latency, all current traffic 200, no false-block events
  - Traefik backup pre-change: `/root/traefik/docker-compose.yml.pre-crowdsec-20260509-061848`

### 4. Backup system rediscovered — already 3-2-1 compliant

- **`/opt/backup-system/backup-docker.sh`** runs daily at 03:00:
  - Restic repo at `r2:netcup-backups` — today's snapshot 746 GiB, daily run completed clean
  - Hetzner Storage Box sync (second offsite tier) — completed 03:55 today
  - Auto-discovers ALL postgres + mariadb containers via `docker ps | grep`
  - Auto-prunes stale snapshots (purged 1.022 GiB today)
  - Health check at 06:00 emails alerts on staleness
- **`/opt/apps/db-backup/`** is a redundant zombie predecessor. Filed as task #7 to decommission.
- **R6 risk reclassified to CLOSED** in the TASK-83 risk register.

## Pending (separate workstreams)

| Task | Owner | Notes |
|------|-------|-------|
| Decommission `/opt/apps/db-backup/` | low priority | Stop + remove `db-backup-cron` container, archive directory |
| Watch for first CrowdSec ban event | passive | Tail `bouncer-traefik` logs for first 403 reject |
| Calendar MCP → SOGo CalDAV | next session | Endpoint live at `mail.rmail.online/SOGo/dav/`, just needs MCP config swap |
| RunPod 90-day spend audit | manual | Login to dashboard, sum costs |
| TASK-83 commit + push (AC 6) | awaiting review | 5 research files + this status doc + cf-access-inventory |

## Files changed on Netcup (live)

| Path | Change |
|------|--------|
| `/root/traefik/docker-compose.yml` | Added `crowdsec@file` to both entrypoint middleware chains |
| `/root/traefik/config/crowdsec.yml` | NEW — forwardAuth middleware definition |
| `/opt/apps/crowdsec/` | NEW — CrowdSec daemon + bouncer compose |
| `/opt/apps/db-backup/rclone.conf` | Switched to `R2_BACKUP_*` creds (rolled into zombie — no functional effect) |
| `/opt/apps/db-backup/backup.sh` | Switched bucket prefix (rolled into zombie — no functional effect) |
| Cloudflare DNS | 37 records: TTL 3600/600 → 300 |

## Files added to dev-ops repo (uncommitted)

```
research/portable-stack/
├── cf-access-inventory/
│   ├── access-inventory.json
│   ├── access-inventory.md
│   ├── access-policies-raw.txt
│   ├── apps-raw.json
│   └── zones.json
├── cf-ttl-scan.sh
└── immediate-wins-status.md  (this file)
```
