#!/bin/bash
# Docker Volume Restore Script
# Restores Docker volumes from Cloudflare R2 backups

set -euo pipefail

source ~/.r2_backup_credentials

RESTORE_DIR="/tmp/restic-restore"

log() {
    echo "[$(date +%Y-%m-%d %H:%M:%S)] $1"
}

# List available snapshots
list_snapshots() {
    log "Available backups:"
    restic snapshots --compact
}

# Restore specific volume
restore_volume() {
    local snapshot="${1:-latest}"
    local volume_name="${2:-}"
    
    if [[ -z "$volume_name" ]]; then
        echo "Usage: $0 restore <snapshot-id|latest> <volume-name>"
        echo "Example: $0 restore latest directus_postgres_data"
        exit 1
    fi
    
    log "Restoring volume: $volume_name from snapshot: $snapshot"
    
    # Create restore directory
    rm -rf "$RESTORE_DIR"
    mkdir -p "$RESTORE_DIR"
    
    # Restore the specific volume
    restic restore "$snapshot" \
        --target "$RESTORE_DIR" \
        --include "/var/lib/docker/volumes/${volume_name}/**"
    
    log "Volume restored to: $RESTORE_DIR/var/lib/docker/volumes/${volume_name}"
    log ""
    log "To apply the restore, stop the container and run:"
    log "  docker compose down"
    log "  rm -rf /var/lib/docker/volumes/${volume_name}/_data/*"
    log "  cp -a $RESTORE_DIR/var/lib/docker/volumes/${volume_name}/_data/* /var/lib/docker/volumes/${volume_name}/_data/"
    log "  docker compose up -d"
}

# Restore database from SQL dump
restore_database() {
    local snapshot="${1:-latest}"
    local container="${2:-}"
    
    if [[ -z "$container" ]]; then
        echo "Usage: $0 restore-db <snapshot-id|latest> <container-name>"
        exit 1
    fi
    
    log "Restoring database for container: $container from snapshot: $snapshot"
    
    rm -rf "$RESTORE_DIR"
    mkdir -p "$RESTORE_DIR"
    
    restic restore "$snapshot" \
        --target "$RESTORE_DIR" \
        --include "/tmp/db-dumps/${container}.sql"
    
    local dump_file="$RESTORE_DIR/tmp/db-dumps/${container}.sql"
    
    if [[ -f "$dump_file" ]]; then
        log "Database dump restored to: $dump_file"
        log ""
        log "To apply the restore, run:"
        log "  docker exec -i $container psql -U postgres < $dump_file"
    else
        log "Error: No database dump found for $container"
        exit 1
    fi
}

# Show help
show_help() {
    echo "Docker Backup Restore Utility"
    echo ""
    echo "Commands:"
    echo "  list                              - List all available snapshots"
    echo "  restore <snapshot> <volume>       - Restore a specific volume"
    echo "  restore-db <snapshot> <container> - Restore a database from SQL dump"
    echo "  diff <snapshot1> <snapshot2>      - Show differences between snapshots"
    echo "  mount <snapshot>                  - Mount a snapshot for browsing"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 restore latest directus_postgres_data"
    echo "  $0 restore-db abc123 directus-postgres-1"
}

case "${1:-help}" in
    list)
        list_snapshots
        ;;
    restore)
        restore_volume "${2:-}" "${3:-}"
        ;;
    restore-db)
        restore_database "${2:-}" "${3:-}"
        ;;
    diff)
        restic diff "${2:-}" "${3:-}"
        ;;
    mount)
        log "Mounting snapshot ${2:-latest} at /mnt/restic-backup"
        mkdir -p /mnt/restic-backup
        restic mount /mnt/restic-backup &
        log "Backup mounted. Browse at /mnt/restic-backup/snapshots/"
        log "Run fusermount -u /mnt/restic-backup when done"
        ;;
    *)
        show_help
        ;;
esac
