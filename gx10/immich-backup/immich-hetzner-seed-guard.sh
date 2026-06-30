#!/bin/bash
# Self-healing seed + auto-cutover for the immich->Hetzner migration.
# Idempotent, safe to run from a */30 cron. State machine:
#   - seed not done            -> clear stale lock + (re)launch seed detached
#                                 (survives reboots: a later tick relaunches)
#   - seed done, nightly on R2 -> verify repo + swap nightly to Hetzner
#   - fully migrated           -> no-op
# NEVER touches the R2 repo. The destructive `restic forget --host spark-be57
# --prune` (drop immich from R2) stays MANUAL. Remove the cron line + this
# script after that drop.
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
source "$HOME/.hetzner_backup_credentials"
LOG="$HOME/immich-hetzner-firstbackup.log"
CUTLOG="$HOME/immich-hetzner-cutover.log"
LOCK="$HOME/.immich-hetzner-guard.lock"

# Single-flight: a prior tick may still be running a long `restic check`.
exec 9>"$LOCK"
flock -n 9 || exit 0

snapshot_exists() {
    restic snapshots --tag gx10-immich --latest 1 --json 2>/dev/null | grep -q gx10-immich
}

# Cheap local check FIRST — while the seed runs (~10h) avoid the slow repo query
# over the seed-saturated SFTP link. If the seed is uploading, no-op.
if pgrep -f 'restic backup .*immich/library .*gx10-immich' >/dev/null 2>&1; then
    exit 0
fi

# Seed is NOT running: it either finished (snapshot saved) or died. SFTP is now
# free, so the repo query is fast.
if snapshot_exists; then
    # Seed complete. Auto-cutover iff the active nightly still targets R2.
    if grep -q "r2_backup_credentials" "$HOME/immich-backup.sh" 2>/dev/null; then
        echo "=== $(date -Is) guard: seed complete -> running cutover ===" >> "$CUTLOG"
        "$HOME/immich-hetzner-cutover.sh" >> "$CUTLOG" 2>&1
        echo "=== $(date -Is) guard: cutover rc=$? ===" >> "$CUTLOG"
    fi
    exit 0
fi

# Seed not running and no snapshot -> it died (e.g. reboot). Relaunch.
echo "=== $(date -Is) seed-guard: (re)starting seed ===" >> "$LOG"
restic unlock >> "$LOG" 2>&1   # clear stale lock from a killed run

setsid nohup restic backup "$HOME/immich/library" \
    --tag gx10-immich --tag "$(date +%F)" \
    --exclude="*.tmp" --exclude="**/.immich" \
    -o sftp.connections=12 >> "$LOG" 2>&1 < /dev/null &

echo "=== $(date -Is) seed-guard: launched pid $! ===" >> "$LOG"
