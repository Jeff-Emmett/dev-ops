#!/bin/bash
# Run AFTER the first immich->Hetzner seed completes. Verifies the Hetzner repo
# then swaps the nightly cron script from the R2 target to the Hetzner target.
# SAFE / additive only: does NOT touch the R2 repo (dropping immich from R2 is a
# separate, confirmed step printed at the end).
set -euo pipefail
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
source "$HOME/.hetzner_backup_credentials"

echo "=== cutover: verify Hetzner repo ==="
restic snapshots --tag gx10-immich --compact
echo "--- structural integrity (metadata) ---"
restic check
echo "--- spot data integrity (5% random pack subset) ---"
restic check --read-data-subset=5%

echo
echo "=== swap nightly script R2 -> Hetzner ==="
if [ ! -f "$HOME/immich-backup.sh.hetzner" ]; then
    echo "ERROR: staged $HOME/immich-backup.sh.hetzner missing" >&2; exit 1
fi
cp -a "$HOME/immich-backup.sh" "$HOME/immich-backup.sh.r2-$(date +%Y%m%d)"
install -m 0755 "$HOME/immich-backup.sh.hetzner" "$HOME/immich-backup.sh"
echo "swapped. active nightly now targets Hetzner. cron unchanged (30 4 * * *)."
echo
echo "NEXT (separate, destructive, confirm first) — drop immich from the R2 repo:"
echo "  source ~/.r2_backup_credentials"
echo "  restic forget --host spark-be57 --prune    # frees ~468 GiB from R2"
