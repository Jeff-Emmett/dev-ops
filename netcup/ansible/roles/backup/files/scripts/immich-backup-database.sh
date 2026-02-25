#!/bin/bash
# Immich Database Backup Script

BACKUP_DIR=~/immich/backups
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/immich-db-$TIMESTAMP.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "Starting database backup: $(date)"

# Use docker compose v2 with service name "database"
cd /opt/immich
docker compose exec -T database pg_dumpall -U postgres | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ] && [ -s "$BACKUP_FILE" ] && [ "$(stat -c%s "$BACKUP_FILE")" -gt 100 ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "Backup successful: $BACKUP_FILE"
    echo "  Size: $SIZE"

    find "$BACKUP_DIR" -name "immich-db-*.sql.gz" -mtime +30 -delete
    COUNT=$(ls -1 "$BACKUP_DIR"/immich-db-*.sql.gz 2>/dev/null | wc -l)
    echo "  Total backups: $COUNT"
else
    echo "Backup failed or empty!"
    rm -f "$BACKUP_FILE"
    exit 1
fi

echo "Backup completed: $(date)"
