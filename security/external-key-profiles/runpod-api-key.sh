#!/usr/bin/env bash
# RunPod API key. Mint: runpod.io → Settings → API Keys. Sourced by ../propagate-external-key.sh
INVENTORY_NAME="runpod-api-key"
KEY_REGEX='^[A-Za-z0-9_-]{20,}$'
CONSUMERS=(
  "local|/home/jeffe/.secrets/private/runpod_api_key|__FILE__"
)
RESTART=()
SMOKE='curl -sf https://api.runpod.io/graphql -H "Content-Type: application/json" -H "Authorization: Bearer $NEW" -d "{\"query\":\"{ myself { id } }\"}" | grep -q "\"id\""'
