# Uptime Kuma DB maintenance runbook

`kuma.db` is SQLite. The `heartbeat` table grows unbounded with monitor
count × frequency × retention. `DELETE` (incl. Kuma's own time-based
`clearOldData`) frees pages **for reuse but does not shrink the file** —
only `VACUUM` returns space to the OS, and `VACUUM` rewrites the whole DB
under an exclusive lock. On this swap-pegged Netcup host, **never** run
bulk `DELETE` + `VACUUM` against a live Kuma — do it offline.

## When to run
- `kuma.db` (docker volume `uptime-kuma_uptime-kuma-data`) > ~1 GB, or
- after lowering `keepDataPeriodDays` (the prune frees pages but won't
  shrink the file until a VACUUM).

Retention is set to **30 days** (`keepDataPeriodDays`, lowered from 180 on
2026-05-20 via the [kuma-alert-agent API path](engine-pool-monitors.md)).
Kuma's hourly `clearOldData` keeps rows time-bounded going forward; this
runbook is the periodic *space-reclaim*, suggested **monthly**.

## Procedure (≈3–5 min status-page downtime — announce/authorise first)

```bash
DB=/var/lib/docker/volumes/uptime-kuma_uptime-kuma-data/_data/kuma.db
BK=/opt/retired/kuma-db-backup-$(date +%F)

# Pre-flight: need > 2× DB size free on /var/lib/docker (backup + VACUUM temp)
df -h /var/lib/docker

# 1. Stop Kuma (clean — checkpoints WAL on shutdown)
cd /opt/apps/uptime-kuma && docker compose stop uptime-kuma

# 2. Backup the quiescent DB FIRST (restore point)
mkdir -p "$BK" && cp -a "$DB" "$BK/kuma.db"

# 3. Baseline integrity + force-merge any residual WAL
sqlite3 "$DB" "PRAGMA integrity_check;"
sqlite3 "$DB" "PRAGMA wal_checkpoint(TRUNCATE);"

# 4. Purge what time-based retention misses, then VACUUM
sqlite3 "$DB" <<'SQL'
.timeout 120000
DELETE FROM heartbeat WHERE monitor_id IN (SELECT id FROM monitor WHERE active=0);
DELETE FROM heartbeat WHERE monitor_id NOT IN (SELECT id FROM monitor);
DELETE FROM heartbeat WHERE time < datetime('now','-30 days');
PRAGMA integrity_check;
VACUUM;
PRAGMA integrity_check;
ANALYZE;
SQL

# 5. Restart + verify
docker compose start uptime-kuma
docker inspect uptime-kuma --format '{{.State.Status}} {{.State.Health.Status}}'
# allow ~10s for Traefik to re-register the backend (a brief 404 during
# that window is normal, NOT a failure), then:
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: status.jeffemmett.com' \
  http://127.0.0.1/dashboard          # expect 200
```

Rollback (any integrity_check != `ok`, or Kuma won't start):
`docker compose stop uptime-kuma && cp -a "$BK/kuma.db" "$DB" && docker compose start uptime-kuma`.
Delete the backup after Kuma is confirmed stable (~7 days).

## 2026-05-20 baseline run (TASK-MEDIUM.16)

| Stage | Result |
|---|---|
| Rows before | 14,484,747 |
| Inactive (`active=0`) deleted | 351,947 |
| Orphan (deleted-monitor) deleted | 5,462 |
| >30 d deleted | 9,486,150 |
| Rows after | 4,641,188 (−68 %) |
| File size | **2.1 GB → 658 MB** |
| integrity_check | `ok` (baseline / post-delete / post-VACUUM) |

Gotcha: the `set_settings`/`api.version` path in `uptime-kuma-api` times
out on this loaded instance (`Event.INFO` never re-emits) — seed
`api._event_data[Event.INFO] = {"version": "1.23.17"}` before the call.
`edit_monitor` is unaffected.
