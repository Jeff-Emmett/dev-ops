#!/bin/bash
# Docker Volume Backup Script
# Backs up all Docker volumes to Cloudflare R2 via Restic
# Also dumps MariaDB/MySQL databases alongside PostgreSQL

set -euo pipefail

# Load credentials
source ~/.r2_backup_credentials

# --- Uptime Kuma push (DB Backup - Daily monitor) ---
KUMA_PUSH_ENV="/etc/uptime-kuma-push.env"
if [[ -r "$KUMA_PUSH_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$KUMA_PUSH_ENV"
fi
push_kuma() {
  local status="$1" msg="$2"
  if [[ -n "${DB_BACKUP_PUSH_TOKEN:-}" ]]; then
    curl -fsS -m 25 -H "Host: status.jeffemmett.com" \
      "http://127.0.0.1/api/push/${DB_BACKUP_PUSH_TOKEN}?status=${status}&msg=${msg// /+}" \
      >/dev/null 2>&1 || true
  fi
}
trap 'rc=$?; if [[ $rc -eq 0 ]]; then push_kuma up OK; else push_kuma down "fail+rc=$rc"; fi' EXIT

# Configuration
BACKUP_LOG="/var/log/docker-backup.log"
# Disk-backed (NOT tmpfs): /tmp is a 32G RAM-backed tmpfs on this host, so a
# large logical dump (e.g. pkmn ~59G) cannot fit and would also eat RAM on a
# memory-tight server. Dumps go to real disk on /dev/vda4 (1.3T free).
DB_DUMP_DIR="/var/backups/db-dumps"
VOLUMES_DIR="/var/lib/docker/volumes"
CONFIG_DIRS="/opt /root/traefik /root/cloudflared /root/KeePass /root/Sync/KeePass /root/.config/keepassxc"
# Per-DB dump timeout. 120s was too short for large DBs (pkmn ~59G silently
# failed every night, mislabeled "access denied"). 1h covers the big ones.
DB_DUMP_TIMEOUT="${DB_DUMP_TIMEOUT:-3600}"

log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1" | tee -a "$BACKUP_LOG"
}

# Pre-backup: Dump SQLite-backed services for crash consistency
dump_sqlite_databases() {
    log "Starting SQLite database dumps..."
    # Vaultwarden — uses SQLite at /data/db.sqlite3.
    # Container image lacks the sqlite3 CLI; use the built-in `/vaultwarden backup`
    # which writes /data/db_<timestamp>.sqlite3 (consistent SQLite snapshot).
    if docker ps --format "{{.Names}}" | grep -q "^vaultwarden$"; then
        if docker exec vaultwarden /vaultwarden backup >/dev/null 2>&1; then
            log "  SUCCESS: vaultwarden SQLite checkpointed via /vaultwarden backup"
            # Trim timestamped backups older than 1 day so the volume stays small.
            docker exec vaultwarden sh -c "find /data -maxdepth 1 -name 'db_*.sqlite3' -mtime +1 -delete" >/dev/null 2>&1 || true
        else
            log "  WARN: vaultwarden /vaultwarden backup failed"
        fi
    fi
}

# Pre-backup: Dump all Postgres databases
dump_postgres_databases() {
    log "Starting PostgreSQL database dumps..."

    for container in $(docker ps --format "{{.Names}}" | grep -iE "postgres|db"); do
        # Check if it actually runs postgres
        if ! docker exec "$container" which pg_dumpall >/dev/null 2>&1; then
            continue
        fi

        # pkmn-db is ~59G; a full logical dump is ~69G and dominates the repo.
        # Dump it WEEKLY (Sundays) only, so daily snapshots stay small. The
        # Sunday snapshot is the last of the ISO week -> kept by keep-weekly.
        if [ "$container" = "pkmn-db" ] && [ "$(date +%u)" -ne 7 ]; then
            log "  SKIP: pkmn-db (weekly dump only; today is not Sunday)"
            continue
        fi

        log "Dumping PostgreSQL: $container"
        pg_user=$(docker exec "$container" printenv POSTGRES_USER 2>/dev/null || echo "postgres")

        if timeout "$DB_DUMP_TIMEOUT" docker exec "$container" pg_dumpall -U "$pg_user" > "$DB_DUMP_DIR/${container}.sql" 2>/dev/null; then
            size=$(du -h "$DB_DUMP_DIR/${container}.sql" | cut -f1)
            log "  SUCCESS: $container ($size)"
        else
            rm -f "$DB_DUMP_DIR/${container}.sql"
            log "  SKIP: $container (access denied or not postgres)"
        fi
    done
}

# Pre-backup: Dump all MariaDB/MySQL databases
dump_mariadb_databases() {
    log "Starting MariaDB/MySQL database dumps..."

    for container in $(docker ps --format "{{.Names}}" | grep -iE "mariadb|mysql"); do
        # Check if it actually runs mysql/mariadb
        if ! docker exec "$container" which mysqldump >/dev/null 2>&1 && \
           ! docker exec "$container" which mariadb-dump >/dev/null 2>&1; then
            continue
        fi

        log "Dumping MariaDB/MySQL: $container"
        root_pw=$(docker exec "$container" printenv MYSQL_ROOT_PASSWORD 2>/dev/null || \
                  docker exec "$container" printenv MARIADB_ROOT_PASSWORD 2>/dev/null || echo "")

        if [ -z "$root_pw" ]; then
            log "  SKIP: $container (no root password found)"
            continue
        fi

        dump_cmd="mysqldump"
        if docker exec "$container" which mariadb-dump >/dev/null 2>&1; then
            dump_cmd="mariadb-dump"
        fi

        if timeout "$DB_DUMP_TIMEOUT" docker exec "$container" $dump_cmd --all-databases -u root -p"$root_pw" > "$DB_DUMP_DIR/${container}.sql" 2>/dev/null; then
            size=$(du -h "$DB_DUMP_DIR/${container}.sql" | cut -f1)
            log "  SUCCESS: $container ($size)"
        else
            rm -f "$DB_DUMP_DIR/${container}.sql"
            log "  FAIL: $container (dump failed)"
        fi
    done
}

# Main backup
run_backup() {
    log "Starting Restic backup..."

    restic backup \
        --verbose \
        --tag docker-volumes \
        --tag "$(date +%Y-%m-%d)" \
        --exclude="*.tmp" \
        --exclude="*.log" \
        --exclude="**/cache/**" \
        --exclude="**/Cache/**" \
        --exclude="**/.cache/**" \
        --exclude="**/node_modules/**" \
        --exclude="**/__pycache__/**" \
        --exclude="**/venv/**" \
        --exclude="**/.git/objects/**" \
        --exclude="/var/lib/docker/volumes/GITEA-ACTIONS-*" \
        --exclude="/var/lib/docker/volumes/pkmn_postgres_data" \
        --exclude="/opt/backups" \
        --exclude="/opt/retired" \
        --exclude="*.osm.pbf" \
        --exclude="**/elevation_cache/**" \
        --exclude="*.gguf" \
        --exclude="**/whisper-local/models/**" \
        --exclude="**/immich_model-cache/**" \
        --exclude="**/p2pwiki-ai/data/chroma/**" \
        --exclude="**/sql-dumps/**" \
        --exclude="core.[0-9][0-9][0-9][0-9]*" \
        --exclude="*.db.bak.*" \
        "$VOLUMES_DIR" \
        "$DB_DUMP_DIR" \
        $CONFIG_DIRS \
        2>&1 | tee -a "$BACKUP_LOG"

    log "Backup completed"
}

# Cleanup old backups (keep 7 daily, 4 weekly, 6 monthly)
cleanup_old_backups() {
    log "Pruning old backups..."
    # --group-by host: ignore the (drifting) path set so all snapshots from this
    # host form ONE retention group. Without it, path changes (e.g. adding a dump
    # dir) fragment retention and snapshots accumulate far past the policy.
    restic forget \
        --group-by host \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 3 \
        --prune \
        2>&1 | tee -a "$BACKUP_LOG"
    log "Prune completed"
}

# Check repository health
check_repository() {
    log "Checking repository integrity..."
    restic check 2>&1 | tee -a "$BACKUP_LOG"
    log "Repository check completed"
}

# Sync DB dumps and local backups to Hetzner Storage Box (second offsite copy)
sync_to_hetzner() {
    if rclone listremotes 2>/dev/null | grep -q "^hetzner:$"; then
        log "Syncing to Hetzner Storage Box..."
        rclone sync "$DB_DUMP_DIR/" hetzner:backups/db-dumps/ \
            --transfers 4 \
            2>&1 | tee -a "$BACKUP_LOG"
        rclone sync /opt/backups/ hetzner:backups/local-backups/ \
            --transfers 4 \
            2>&1 | tee -a "$BACKUP_LOG"
        log "Hetzner sync completed"
    else
        log "WARN: Hetzner remote not configured, skipping offsite sync"
    fi
}

# Main execution
main() {
    log "=========================================="
    log "Starting Docker backup to Cloudflare R2"
    log "=========================================="

    # Prepare dump directory
    rm -rf "$DB_DUMP_DIR"
    mkdir -p "$DB_DUMP_DIR"

    dump_sqlite_databases
    dump_postgres_databases
    dump_mariadb_databases
    run_backup
    cleanup_old_backups
    sync_to_hetzner

    # Run integrity check weekly (on Sundays)
    if [ "$(date +%u)" -eq 7 ]; then
        check_repository
    fi

    # Remove empty dump files
    find "$DB_DUMP_DIR" -size 0 -delete 2>/dev/null || true

    log "All backup tasks completed successfully"
    log "=========================================="
}

main "$@"
