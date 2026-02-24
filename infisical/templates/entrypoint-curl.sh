#!/bin/sh
# Infisical secret injection entrypoint (curl+jq)
# For images without Python or Node.js (e.g., Rust/Go binaries on minimal base images)
# Required env vars: INFISICAL_CLIENT_ID, INFISICAL_CLIENT_SECRET
# Optional: INFISICAL_PROJECT_SLUG, INFISICAL_ENV (default: prod),
#           INFISICAL_URL (default: http://infisical:8080)
#
# Prerequisites: curl and jq must be installed in the image

set -e

export INFISICAL_URL="${INFISICAL_URL:-http://infisical:8080}"
export INFISICAL_ENV="${INFISICAL_ENV:-prod}"
# IMPORTANT: Set INFISICAL_PROJECT_SLUG in your docker-compose.yml
export INFISICAL_PROJECT_SLUG="${INFISICAL_PROJECT_SLUG:?INFISICAL_PROJECT_SLUG must be set}"

if [ -z "$INFISICAL_CLIENT_ID" ] || [ -z "$INFISICAL_CLIENT_SECRET" ]; then
  echo "[infisical] No credentials set, starting without secret injection"
  exec "$@"
fi

echo "[infisical] Fetching secrets from ${INFISICAL_PROJECT_SLUG}/${INFISICAL_ENV}..."

# Authenticate
AUTH_RESPONSE=$(curl -sf -X POST "${INFISICAL_URL}/api/v1/auth/universal-auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"${INFISICAL_CLIENT_ID}\",\"clientSecret\":\"${INFISICAL_CLIENT_SECRET}\"}") || {
  echo "[infisical] WARNING: Auth failed, starting with existing env vars"
  exec "$@"
}

TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.accessToken')
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "[infisical] WARNING: No token received, starting with existing env vars"
  exec "$@"
fi

# Fetch secrets
SECRETS=$(curl -sf "${INFISICAL_URL}/api/v3/secrets/raw?workspaceSlug=${INFISICAL_PROJECT_SLUG}&environment=${INFISICAL_ENV}&secretPath=/&recursive=true" \
  -H "Authorization: Bearer ${TOKEN}") || {
  echo "[infisical] WARNING: Failed to fetch secrets, starting with existing env vars"
  exec "$@"
}

# Parse and export using jq's @sh for proper escaping
EXPORTS=$(echo "$SECRETS" | jq -r '.secrets[]? | "export " + .secretKey + "=" + (.secretValue | @sh)')

if [ -n "$EXPORTS" ]; then
  COUNT=$(echo "$EXPORTS" | grep -c "^export " || true)
  eval "$EXPORTS"
  echo "[infisical] Injected ${COUNT} secrets"
else
  echo "[infisical] WARNING: No secrets found"
fi

exec "$@"
