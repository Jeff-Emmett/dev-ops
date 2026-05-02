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
DB_DUMP_DIR="/tmp/db-dumps"
VOLUMES_DIR="/var/lib/docker/volumes"
CONFIG_DIRS="/opt /root/traefik /root/cloudflared"

log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1" | tee -a "$BACKUP_LOG"
}

# Pre-backup: Dump all Postgres databases
dump_postgres_databases() {
    log "Starting PostgreSQL database dumps..."

    for container in $(docker ps --format "{{.Names}}" | grep -iE "postgres|db"); do
        # Check if it actually runs postgres
        if ! docker exec "$container" which pg_dumpall >/dev/null 2>&1; then
            continue
        fi

        log "Dumping PostgreSQL: $container"
        pg_user=$(docker exec "$container" printenv POSTGRES_USER 2>/dev/null || echo "postgres")

        if timeout 120 docker exec "$container" pg_dumpall -U "$pg_user" > "$DB_DUMP_DIR/${container}.sql" 2>/dev/null; then
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

        if timeout 120 docker exec "$container" $dump_cmd --all-databases -u root -p"$root_pw" > "$DB_DUMP_DIR/${container}.sql" 2>/dev/null; then
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
        "$VOLUMES_DIR" \
        "$DB_DUMP_DIR" \
        $CONFIG_DIRS \
        2>&1 | tee -a "$BACKUP_LOG"

    log "Backup completed"
}

# Cleanup old backups (keep 7 daily, 4 weekly, 6 monthly)
cleanup_old_backups() {
    log "Pruning old backups..."
    restic forget \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 6 \
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
