#!/bin/bash
source "$HOME/.hetzner_backup_credentials"
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
echo "=== $(date -Is) first immich->Hetzner backup start ==="
restic backup "$HOME/immich/library" \
  --tag gx10-immich --tag "$(date +%F)" \
  --exclude="*.tmp" --exclude="**/.immich" \
  -o sftp.connections=12 --verbose
echo "=== $(date -Is) done rc=$? ==="
