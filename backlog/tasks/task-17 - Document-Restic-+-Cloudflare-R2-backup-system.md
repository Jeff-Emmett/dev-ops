---
id: task-17
title: Document Restic + Cloudflare R2 backup system
status: Done
assignee: []
created_date: '2026-01-30 14:25'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Summary
Implemented a Docker-native backup strategy using Restic with Cloudflare R2 as the storage backend (instead of AWS S3). This provides encrypted, deduplicated, incremental backups of all Docker volumes and configuration files on the Netcup RS 8000 server.

## Implementation Details

### Components Installed
- **Restic v0.18.0** - Backup tool with encryption and deduplication
- **Cloudflare R2 bucket** - `netcup-backups` (S3-compatible, zero egress fees)

### Files Created on Netcup
- `/opt/backup-system/backup-docker.sh` - Main backup script
- `/opt/backup-system/restore-docker.sh` - Restore helper script  
- `/opt/backup-system/backup-status.sh` - Quick status check
- `~/.r2_backup_credentials` - R2 + Restic credentials (chmod 600)
- Credentials also documented in `~/.cloudflare-credentials.env`

### What Gets Backed Up
- `/var/lib/docker/volumes/` - All Docker volumes (~110GB)
- `/opt/` - Application deployments
- `/root/traefik/` - Reverse proxy config
- `/root/cloudflared/` - Tunnel config
- `/tmp/db-dumps/` - Pre-backup Postgres dumps

### Automation
- **Cron job**: Daily at 3:00 AM
- **Retention**: 7 daily, 4 weekly, 6 monthly snapshots
- **Integrity check**: Weekly on Sundays

### First Backup Stats
- Snapshot ID: f5bde978
- Files: 640,672
- Original: 586.6 GiB
- Compressed: 522.2 GiB
- Duration: 2h 15m (initial full backup)

### Cost
- R2 Storage: ~$7.83/month (522 GB × $0.015/GB)
- Zero egress fees for restores
- Significant savings vs AWS S3

### Credentials (stored securely on Netcup)
- Restic encryption password in `~/.r2_backup_credentials`
- R2 API keys in `~/.r2_backup_credentials` and `~/.cloudflare-credentials.env`
- **CRITICAL**: Backup password required for restore - stored in password manager

### Quick Commands
```bash
ssh netcup
/opt/backup-system/backup-status.sh           # Check status
/opt/backup-system/backup-docker.sh           # Manual backup
source ~/.r2_backup_credentials && restic snapshots  # List backups
/opt/backup-system/restore-docker.sh list     # List for restore
/opt/backup-system/restore-docker.sh restore latest <volume>  # Restore
```
<!-- SECTION:DESCRIPTION:END -->
