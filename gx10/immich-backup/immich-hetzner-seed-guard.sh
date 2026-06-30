#!/bin/bash
# Self-healing seed for the immich->Hetzner migration. Idempotent:
#   - if a complete gx10-immich snapshot already exists -> done, exit 0
#   - if a seed is already running -> exit 0
#   - else clear any stale lock and (re)start the full seed, detached
# Wired to @reboot AND run manually, so a mid-seed reboot self-recovers.
# restic resumes from already-uploaded blobs via dedup (no re-upload).
# REMOVE the @reboot cron line + this script once cutover is done.
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
source "$HOME/.hetzner_backup_credentials"
LOG="$HOME/immich-hetzner-firstbackup.log"

# Already migrated? restic only persists a snapshot on success.
if restic snapshots --tag gx10-immich --latest 1 --json 2>/dev/null | grep -q gx10-immich; then
    exit 0
fi

# Already seeding?
if pgrep -f 'restic backup .*immich/library .*gx10-immich' >/dev/null 2>&1; then
    exit 0
fi

echo "=== $(date -Is) seed-guard: (re)starting seed ===" >> "$LOG"
restic unlock >> "$LOG" 2>&1   # clear stale lock from a killed run

setsid nohup restic backup "$HOME/immich/library" \
    --tag gx10-immich --tag "$(date +%F)" \
    --exclude="*.tmp" --exclude="**/.immich" \
    -o sftp.connections=12 >> "$LOG" 2>&1 < /dev/null &

echo "=== $(date -Is) seed-guard: launched pid $! ===" >> "$LOG"
