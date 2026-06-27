#!/bin/bash
# GX10 -> Hetzner Storage Box restic backup of the immich library.
# Replaces the former shared-R2 target (migrated 2026-06-27). Unlike the R2
# repo (which netcup prunes), gx10 is the SOLE writer of hetzner:immich-backups,
# so this script also runs its own forget (+ weekly prune).
set -o pipefail
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
source "$HOME/.hetzner_backup_credentials"   # RESTIC_REPOSITORY=sftp:hetzner-box:immich-backups + RESTIC_PASSWORD
LOG="$HOME/immich-backup.log"

echo "=== $(date -Is) immich->Hetzner backup start ===" >> "$LOG"

# apps first, library last: forget --group-by host --keep-daily keeps only the
# LATEST spark-be57 snapshot per day -> the 468G library wins the slot; apps
# (tiny, also in Gitea) intentionally yields it. Same rationale as the old R2
# script (see immich-backup.sh.bak-20260625).
restic backup "$HOME/immich/search-app" "$HOME/immich/heatmap-app" \
    --tag gx10-apps --tag "$(date +%F)" \
    --exclude="**/node_modules/**" \
    -o sftp.connections=12 >> "$LOG" 2>&1
echo "apps rc=$? $(date -Is)" >> "$LOG"

# Library: STABLE single-path set so restic parent-matches the prior snapshot
# and only reads changed files. Runs LAST -> most-recent spark-be57 snapshot of
# the day -> wins keep-daily slot. This is the snapshot freshness-monitored.
restic backup "$HOME/immich/library" \
    --tag gx10-immich --tag "$(date +%F)" \
    --exclude="*.tmp" --exclude="**/.immich" \
    -o sftp.connections=12 >> "$LOG" 2>&1
echo "library rc=$? $(date -Is)" >> "$LOG"

# Retention. forget (cheap, ref-only) nightly; prune (exclusive lock + repack,
# heavy over SFTP) only Sundays. group-by host = one spark-be57 group.
restic forget --group-by host \
    --keep-daily 7 --keep-weekly 4 --keep-monthly 6 >> "$LOG" 2>&1
echo "forget rc=$? $(date -Is)" >> "$LOG"
if [ "$(date +%u)" -eq 7 ]; then
    restic prune >> "$LOG" 2>&1
    echo "prune rc=$? $(date -Is)" >> "$LOG"
fi
echo "=== $(date -Is) immich->Hetzner backup end ===" >> "$LOG"
