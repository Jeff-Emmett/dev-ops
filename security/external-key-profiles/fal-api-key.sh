#!/usr/bin/env bash
# fal.ai API key. Mint: fal.ai dashboard → Keys. Sourced by ../propagate-external-key.sh
INVENTORY_NAME="fal-api-key"
KEY_REGEX='^[A-Za-z0-9_:-]{20,}$'
CONSUMERS=(
  "netcup|/opt/secrets/fal/.env|FAL_KEY"
)
RESTART=()   # fal is consumed by short-lived jobs that re-read the .env; nothing long-lived to restart
SMOKE='curl -sf -H "Authorization: Key $NEW" https://rest.alpha.fal.ai/auth/whoami >/dev/null'
