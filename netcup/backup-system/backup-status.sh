#!/bin/bash
# Quick backup status check
source ~/.r2_backup_credentials

echo "=== Restic Backup Status ==="
echo ""
echo "Latest snapshots:"
restic snapshots --compact --last 5
echo ""
echo "Repository stats:"
restic stats --mode raw-data
echo ""
echo "Last backup log:"
tail -30 /var/log/docker-backup.log 2>/dev/null || echo "No backup log found yet"
