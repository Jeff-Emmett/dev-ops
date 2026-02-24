#!/bin/bash
# Migrate a .env file's secrets into an Infisical project
# Usage: ./migrate-env.sh <env-file> <project-slug> [environment]
#
# Prerequisites:
#   - INFISICAL_TOKEN env var set (identity with write access to the project)
#   - INFISICAL_URL env var or defaults to https://secrets.jeffemmett.com
#
# What this does:
#   1. Reads the .env file
#   2. Skips comments, empty lines, and INFISICAL_* vars
#   3. Creates each secret in the Infisical project
#   4. Reports success/failure for each secret

set -euo pipefail

ENV_FILE="${1:?Usage: $0 <env-file> <project-slug> [environment]}"
PROJECT_SLUG="${2:?Usage: $0 <env-file> <project-slug> [environment]}"
ENVIRONMENT="${3:-prod}"
INFISICAL_URL="${INFISICAL_URL:-https://secrets.jeffemmett.com}"

if [ -z "${INFISICAL_TOKEN:-}" ]; then
  echo "ERROR: INFISICAL_TOKEN must be set"
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: File not found: $ENV_FILE"
  exit 1
fi

API="${INFISICAL_URL}/api"
AUTH="Authorization: Bearer ${INFISICAL_TOKEN}"

echo "=== Migrating ${ENV_FILE} → ${PROJECT_SLUG}/${ENVIRONMENT} ==="

SUCCESS=0
FAILED=0
SKIPPED=0

while IFS= read -r line || [ -n "$line" ]; do
  # Skip comments and empty lines
  case "$line" in
    \#*|"") SKIPPED=$((SKIPPED + 1)); continue ;;
  esac

  # Extract key=value (handle values with = in them)
  KEY="${line%%=*}"
  VALUE="${line#*=}"

  # Skip INFISICAL_* vars (they're meta, not app secrets)
  case "$KEY" in
    INFISICAL_*) echo "  SKIP: ${KEY} (infisical meta var)"; SKIPPED=$((SKIPPED + 1)); continue ;;
  esac

  # Strip surrounding quotes from value if present
  case "$VALUE" in
    \"*\") VALUE="${VALUE#\"}"; VALUE="${VALUE%\"}" ;;
    \'*\') VALUE="${VALUE#\'}"; VALUE="${VALUE%\'}" ;;
  esac

  # Escape for JSON
  JSON_VALUE=$(printf '%s' "$VALUE" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()), end="")')

  # Create secret via API
  RESPONSE=$(curl -sf -X POST "${API}/v3/secrets/raw/${KEY}" \
    -H "${AUTH}" \
    -H "Content-Type: application/json" \
    -d "{\"workspaceSlug\":\"${PROJECT_SLUG}\",\"environment\":\"${ENVIRONMENT}\",\"secretPath\":\"/\",\"secretValue\":${JSON_VALUE},\"type\":\"shared\"}" 2>&1) && {
    echo "  OK: ${KEY}"
    SUCCESS=$((SUCCESS + 1))
  } || {
    # Try update if create failed (secret might already exist)
    RESPONSE=$(curl -sf -X PATCH "${API}/v3/secrets/raw/${KEY}" \
      -H "${AUTH}" \
      -H "Content-Type: application/json" \
      -d "{\"workspaceSlug\":\"${PROJECT_SLUG}\",\"environment\":\"${ENVIRONMENT}\",\"secretPath\":\"/\",\"secretValue\":${JSON_VALUE}}" 2>&1) && {
      echo "  UPDATED: ${KEY}"
      SUCCESS=$((SUCCESS + 1))
    } || {
      echo "  FAILED: ${KEY} - ${RESPONSE}"
      FAILED=$((FAILED + 1))
    }
  }
done < "$ENV_FILE"

echo ""
echo "=== Migration complete ==="
echo "  Success: ${SUCCESS}"
echo "  Failed:  ${FAILED}"
echo "  Skipped: ${SKIPPED}"

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "WARNING: ${FAILED} secrets failed to migrate. Check output above."
  exit 1
fi
