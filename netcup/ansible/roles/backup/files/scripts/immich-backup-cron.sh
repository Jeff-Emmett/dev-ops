#!/bin/bash
# Daily Immich database backup script

cd /opt/immich
./backup-database.sh

# Keep only last 7 days of backups
find /opt/immich/backups -name "immich-db-*.sql.gz" -mtime +7 -delete
