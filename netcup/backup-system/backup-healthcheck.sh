#!/bin/bash
# Backup Health Check Script
# Checks all backup systems and emails alerts on failure

set -euo pipefail

FAIL_COUNT=0
WARN_COUNT=0
LOG="/var/log/backup-healthcheck.log"
REPORT=""

log() { echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG"; }
fail() { log "FAIL: $1"; REPORT="${REPORT}FAIL: $1\n"; FAIL_COUNT=$((FAIL_COUNT+1)); }
warn() { log "WARN: $1"; REPORT="${REPORT}WARN: $1\n"; WARN_COUNT=$((WARN_COUNT+1)); }
ok()   { log "OK: $1"; REPORT="${REPORT}OK: $1\n"; }

check_restic() {
    . ~/.r2_backup_credentials
    local latest_time
    latest_time=$(restic snapshots --latest 1 --compact 2>/dev/null | grep -oP '\d{4}-\d{2}-\d{2}' | tail -1 || true)

    if [ -z "$latest_time" ]; then
        fail "Restic: No snapshots found or repo unreachable"
        return
    fi

    local today
    today=$(date +%Y-%m-%d)
    local yesterday
    yesterday=$(date -d "yesterday" +%Y-%m-%d)

    if [ "$latest_time" != "$today" ] && [ "$latest_time" != "$yesterday" ]; then
        fail "Restic: Last backup is from $latest_time (stale)"
    else
        ok "Restic last backup: $latest_time"
    fi
}

check_immich_backup() {
    local latest
    latest=$(ls -t ~/immich/backups/immich-db-*.sql.gz 2>/dev/null | head -1 || true)
    if [ -z "$latest" ]; then
        fail "Immich DB: No backup files found"
        return
    fi

    local size
    size=$(stat -c%s "$latest" 2>/dev/null || echo 0)
    if [ "$size" -lt 100 ]; then
        fail "Immich DB: Latest backup is empty ($latest, ${size} bytes)"
    else
        ok "Immich DB backup: $latest ($(du -h "$latest" | cut -f1))"
    fi
}

check_db_dumps() {
    local dump_dir="/tmp/db-dumps"
    if [ ! -d "$dump_dir" ] || [ -z "$(ls -A "$dump_dir" 2>/dev/null)" ]; then
        warn "DB dumps: /tmp/db-dumps is empty (will be populated on next backup run)"
        return
    fi

    for db in erpnext-mariadb mailcowdockerized-mysql-mailcow-1 immich_postgres gitea-db; do
        local dump="$dump_dir/${db}.sql"
        if [ ! -f "$dump" ]; then
            warn "DB dump missing: $db"
        elif [ "$(stat -c%s "$dump")" -lt 100 ]; then
            fail "DB dump empty: $db"
        else
            ok "DB dump: $db ($(du -h "$dump" | cut -f1))"
        fi
    done
}

check_disk_space() {
    local usage
    usage=$(df / --output=pcent | tail -1 | tr -d ' %')
    if [ "$usage" -gt 90 ]; then
        fail "Disk: Root filesystem at ${usage}% (critical)"
    elif [ "$usage" -gt 80 ]; then
        warn "Disk: Root filesystem at ${usage}%"
    else
        ok "Disk usage at ${usage}%"
    fi
}

check_docker_health() {
    local unhealthy
    unhealthy=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null || true)
    if [ -n "$unhealthy" ]; then
        warn "Unhealthy containers: $unhealthy"
    else
        ok "All containers healthy"
    fi
}

send_email_alert() {
    local subject="$1"
    local body="$2"
    python3 /opt/backup-system/send-alert.py "$subject" "$body" 2>&1 | tee -a "$LOG"
}

main() {
    log "=========================================="
    log "Backup Health Check"
    log "=========================================="

    check_restic
    check_immich_backup
    check_db_dumps
    check_disk_space
    check_docker_health

    echo ""
    local summary="Failures: $FAIL_COUNT | Warnings: $WARN_COUNT"
    log "$summary"
    log "=========================================="

    # Send email alert if there are failures
    if [ "$FAIL_COUNT" -gt 0 ]; then
        local body
        body=$(printf "Backup Health Check Report\n========================\n\n%b\n\nSummary: %s\nServer: $(hostname)\nTime: $(date)" "$REPORT" "$summary")
        send_email_alert "[BACKUP ALERT] $FAIL_COUNT failure(s) on $(hostname)" "$body"
        return 1
    fi

    # Send warning email (optional - only on warnings without failures)
    if [ "$WARN_COUNT" -gt 0 ]; then
        local body
        body=$(printf "Backup Health Check Report\n========================\n\n%b\n\nSummary: %s\nServer: $(hostname)\nTime: $(date)" "$REPORT" "$summary")
        send_email_alert "[BACKUP WARN] $WARN_COUNT warning(s) on $(hostname)" "$body"
    fi

    return 0
}

main "$@"
