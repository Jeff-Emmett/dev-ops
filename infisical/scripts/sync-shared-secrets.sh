#!/bin/bash
# sync-shared-secrets.sh — Sync shared keys from claude-ops to per-service projects
# Run after rotating any shared API key (RunPod, Gemini, FAL, etc.)
#
# Usage:
#   sync-shared-secrets           # sync all shared keys to all projects
#   sync-shared-secrets RUNPOD    # sync only keys matching "RUNPOD"
#
set -euo pipefail

# Try internal URL first (avoids CF Access), fall back to external
if curl -sf --connect-timeout 2 "http://172.27.0.6:8080/api/status" > /dev/null 2>&1; then
  INFISICAL_URL="http://172.27.0.6:8080"
  echo "Using internal Infisical URL"
else
  INFISICAL_URL="https://secrets.jeffemmett.com"
  echo "Using external Infisical URL"
fi
CLAUDE_OPS_ID="5b64ec1b-5b67-4b48-8808-c2465c0be41a"

# Bootstrap auth
if [ -f /opt/infisical/claude-ops.env ]; then
  source /opt/infisical/claude-ops.env
elif [ -f "$HOME/.secrets/infisical_admin_client_id" ]; then
  INFISICAL_CLIENT_ID=$(cat "$HOME/.secrets/infisical_admin_client_id")
  INFISICAL_CLIENT_SECRET=$(cat "$HOME/.secrets/infisical_admin_client_secret")
else
  echo "ERROR: No Infisical credentials found" >&2
  exit 1
fi

TOKEN=$(curl -sf -X POST "$INFISICAL_URL/api/v1/auth/universal-auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\": \"$INFISICAL_CLIENT_ID\", \"clientSecret\": \"$INFISICAL_CLIENT_SECRET\"}" | jq -r '.accessToken')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "Auth failed" >&2; exit 1
fi

FILTER="${1:-}"

# Define shared key mappings: source_folder/KEY -> list of target project slugs
# Format: "source_path KEY target_slug1 target_slug2 ..."
SHARED_KEYS=(
  "/ai RUNPOD_API_KEY mycofi personal-dashboard pkmn-app"
  "/ai GEMINI_API_KEY mycofi personal-dashboard"
  "/ai FAL_KEY mycofi"
  "/cloudflare CLOUDFLARE_API_TOKEN personal-dashboard"
  "/cloudflare CLOUDFLARE_ANALYTICS_TOKEN personal-dashboard"
  "/git GITEA_TOKEN personal-dashboard"
  "/git GITHUB_TOKEN personal-dashboard"
  "/ai LITELLM_MASTER_KEY open-claw-iron rtrips-online"
  "/ai LITELLM_API_KEY open-claw-iron rtrips-online"
  "/bridge BRIDGE_API_KEY rmesh-reticulum rmesh-online"
)

synced=0
skipped=0
failed=0

for mapping in "${SHARED_KEYS[@]}"; do
  read -r src_path key targets <<< "$mapping"

  # Apply filter if specified
  if [ -n "$FILTER" ] && [[ "$key" != *"$FILTER"* ]]; then
    continue
  fi

  # Get source value from claude-ops
  val=$(curl -sf "$INFISICAL_URL/api/v3/secrets/raw/$key?workspaceId=$CLAUDE_OPS_ID&environment=prod&secretPath=$src_path" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.secret.secretValue')

  if [ -z "$val" ] || [ "$val" = "null" ]; then
    echo "SKIP: $key — not found in claude-ops $src_path"
    skipped=$((skipped + 1))
    continue
  fi

  val_escaped=$(echo -n "$val" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" | sed 's/^"//;s/"$//')

  for target in $targets; do
    # Get target project ID
    target_id=$(curl -sf "$INFISICAL_URL/api/v1/workspace" \
      -H "Authorization: Bearer $TOKEN" | jq -r ".workspaces[] | select(.slug==\"$target\") | .id")

    if [ -z "$target_id" ] || [ "$target_id" = "null" ]; then
      echo "FAIL: $key → $target (project not found)"
      failed=$((failed + 1))
      continue
    fi

    # Check current value in target (may 404 if secret doesn't exist yet)
    current=$(curl -s "$INFISICAL_URL/api/v3/secrets/raw/$key?workspaceId=$target_id&environment=prod&secretPath=/" \
      -H "Authorization: Bearer $TOKEN" | jq -r '.secret.secretValue // empty')

    if [ "$current" = "$val" ]; then
      echo "  OK: $key → $target (already in sync)"
      skipped=$((skipped + 1))
      continue
    fi

    # Update or create
    result=$(curl -s -X PATCH "$INFISICAL_URL/api/v3/secrets/raw/$key" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"workspaceId\":\"$target_id\",\"environment\":\"prod\",\"secretPath\":\"/\",\"secretValue\":\"$val_escaped\"}")

    if echo "$result" | jq -e '.secret' > /dev/null 2>&1; then
      echo "  SYNCED: $key → $target"
      synced=$((synced + 1))
    else
      # Try create if patch fails
      result=$(curl -s -X POST "$INFISICAL_URL/api/v3/secrets/raw/$key" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"workspaceId\":\"$target_id\",\"environment\":\"prod\",\"secretPath\":\"/\",\"secretValue\":\"$val_escaped\",\"type\":\"shared\"}")
      if echo "$result" | jq -e '.secret' > /dev/null 2>&1; then
        echo "  CREATED: $key → $target"
        synced=$((synced + 1))
      else
        echo "  FAIL: $key → $target"
        failed=$((failed + 1))
      fi
    fi
  done
done

echo ""
echo "Summary: $synced synced, $skipped already in sync, $failed failed"
