#!/bin/bash
# Batch migration: Tier 1B - Remaining custom apps
# Creates Infisical projects and pushes initial secrets
#
# Services: ai-orchestrator, semantic-search, p2pwiki, schedule,
#           grid-trading-bot, personal-dashboard, clip-forge, open-claw-iron
#
# Usage: Run from dev-ops/infisical/scripts/ directory
# Prerequisites: INFISICAL_ADMIN_CLIENT_ID and INFISICAL_ADMIN_CLIENT_SECRET set

set -euo pipefail

INFISICAL_URL="https://secrets.jeffemmett.com"
ORG_ID="091129af-53a7-45e2-83b5-cda045203ab8"

# Read admin credentials
ADMIN_CLIENT_ID=$(cat ~/.secrets/infisical_admin_client_id)
ADMIN_CLIENT_SECRET=$(cat ~/.secrets/infisical_admin_client_secret)

echo "=== Tier 1B Migration ==="
echo "Authenticating..."

TOKEN=$(curl -sf -X POST "${INFISICAL_URL}/api/v1/auth/universal-auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"${ADMIN_CLIENT_ID}\",\"clientSecret\":\"${ADMIN_CLIENT_SECRET}\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

echo "Auth OK"

# Helper: create project
create_project() {
  local name="$1" slug="$2"
  echo ""
  echo "--- Creating project: ${name} (${slug}) ---"
  RESULT=$(curl -sf -X POST "${INFISICAL_URL}/api/v2/workspace" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"projectName\":\"${name}\",\"slug\":\"${slug}\",\"organizationId\":\"${ORG_ID}\"}")
  PROJECT_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['workspace']['id'])" 2>/dev/null || echo "FAILED")
  if [ "$PROJECT_ID" = "FAILED" ]; then
    echo "  WARN: Project creation failed (may already exist): $RESULT"
    return 1
  fi
  echo "  Project ID: ${PROJECT_ID}"
  echo "$PROJECT_ID"
}

# Helper: push a secret
push_secret() {
  local slug="$1" key="$2" value="$3"
  ESCAPED_VALUE=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$value")
  curl -sf -X POST "${INFISICAL_URL}/api/v3/secrets/raw/${key}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"projectSlug\":\"${slug}\",\"environment\":\"prod\",\"secretPath\":\"/\",\"secretValue\":${ESCAPED_VALUE},\"type\":\"shared\"}" > /dev/null
  echo "  Pushed: ${key}"
}

# Helper: create machine identity
create_identity() {
  local name="$1" project_id="$2"
  # Create identity
  ID_RESULT=$(curl -sf -X POST "${INFISICAL_URL}/api/v1/identities" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${name}\",\"organizationId\":\"${ORG_ID}\",\"role\":\"member\"}")
  IDENTITY_ID=$(echo "$ID_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['identity']['id'])" 2>/dev/null || echo "FAILED")
  if [ "$IDENTITY_ID" = "FAILED" ]; then
    echo "  WARN: Identity creation failed: $ID_RESULT"
    return 1
  fi
  echo "  Identity ID: ${IDENTITY_ID}"

  # Create universal auth
  AUTH_RESULT=$(curl -sf -X POST "${INFISICAL_URL}/api/v1/auth/universal-auth/identities/${IDENTITY_ID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{}')
  CLIENT_ID=$(echo "$AUTH_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['identityUniversalAuth']['clientId'])" 2>/dev/null || echo "FAILED")
  echo "  Client ID: ${CLIENT_ID}"

  # Create client secret
  SECRET_RESULT=$(curl -sf -X POST "${INFISICAL_URL}/api/v1/auth/universal-auth/identities/${IDENTITY_ID}/client-secrets" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{}')
  CLIENT_SECRET=$(echo "$SECRET_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientSecret'])" 2>/dev/null || echo "FAILED")
  echo "  Client Secret: ${CLIENT_SECRET:0:12}..."

  # Add to project as viewer
  curl -sf -X POST "${INFISICAL_URL}/api/v2/workspace/${project_id}/memberships" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"identityId\":\"${IDENTITY_ID}\",\"role\":\"viewer\"}" > /dev/null 2>&1 || true

  echo "${name}|${CLIENT_ID}|${CLIENT_SECRET}" >> /tmp/infisical-tier1b-creds.txt
}

# Clear old creds file
> /tmp/infisical-tier1b-creds.txt
chmod 600 /tmp/infisical-tier1b-creds.txt

echo ""
echo "========================================="
echo "1. AI Orchestrator"
echo "========================================="
PROJECT_ID=$(create_project "AI Orchestrator" "ai-orchestrator") || true
if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "FAILED" ]; then
  push_secret "ai-orchestrator" "RUNPOD_API_KEY" "PLACEHOLDER_COPY_FROM_NETCUP"
  create_identity "ai-orchestrator-container" "$PROJECT_ID"
fi

echo ""
echo "========================================="
echo "2. Semantic Search"
echo "========================================="
PROJECT_ID=$(create_project "Semantic Search" "semantic-search") || true
if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "FAILED" ]; then
  push_secret "semantic-search" "EXA_API_KEY" "PLACEHOLDER"
  create_identity "semantic-search-container" "$PROJECT_ID"
fi

echo ""
echo "========================================="
echo "3. P2P Wiki Content"
echo "========================================="
PROJECT_ID=$(create_project "P2P Wiki Content" "p2pwiki") || true
if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "FAILED" ]; then
  push_secret "p2pwiki" "ANTHROPIC_API_KEY" "PLACEHOLDER_COPY_FROM_NETCUP"
  create_identity "p2pwiki-container" "$PROJECT_ID"
fi

echo ""
echo "========================================="
echo "4. Schedule Jeff Emmett"
echo "========================================="
PROJECT_ID=$(create_project "Schedule Jeff Emmett" "schedule") || true
if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "FAILED" ]; then
  # Generate secure passwords for new deployment
  DB_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
  ADMIN_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
  SESSION_SEC=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  CANCEL_SEC=$(python3 -c "import secrets; print(secrets.token_hex(32))")

  push_secret "schedule" "DATABASE_URL" "postgresql://schedule:${DB_PASS}@schedule-postgres:5432/schedule"
  push_secret "schedule" "POSTGRES_PASSWORD" "${DB_PASS}"
  push_secret "schedule" "ADMIN_PASSWORD" "${ADMIN_PASS}"
  push_secret "schedule" "SESSION_SECRET" "${SESSION_SEC}"
  push_secret "schedule" "CANCEL_TOKEN_SECRET" "${CANCEL_SEC}"
  push_secret "schedule" "GOOGLE_CLIENT_ID" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "schedule" "GOOGLE_CLIENT_SECRET" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "schedule" "SMTP_USER" "noreply@jeffemmett.com"
  push_secret "schedule" "SMTP_PASS" "PLACEHOLDER_COPY_FROM_NETCUP"
  create_identity "schedule-container" "$PROJECT_ID"
fi

echo ""
echo "========================================="
echo "5. Grid Trading Bot"
echo "========================================="
PROJECT_ID=$(create_project "Grid Trading Bot" "grid-trading-bot") || true
if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "FAILED" ]; then
  DB_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
  push_secret "grid-trading-bot" "DATABASE_URL" "postgres://gridbot:${DB_PASS}@grid-trading-db:5432/grid_trading"
  push_secret "grid-trading-bot" "POSTGRES_PASSWORD" "${DB_PASS}"
  push_secret "grid-trading-bot" "NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "grid-trading-bot" "ONEINCH_API_KEY" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "grid-trading-bot" "TELEGRAM_BOT_TOKEN" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "grid-trading-bot" "TELEGRAM_CHAT_ID" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "grid-trading-bot" "ARBITRUM_RPC_URL" "https://arb1.arbitrum.io/rpc"
  create_identity "grid-trading-bot-container" "$PROJECT_ID"
fi

echo ""
echo "========================================="
echo "6. Personal Dashboard"
echo "========================================="
PROJECT_ID=$(create_project "Personal Dashboard" "personal-dashboard") || true
if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "FAILED" ]; then
  push_secret "personal-dashboard" "GITEA_TOKEN" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "personal-dashboard" "GITHUB_TOKEN" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "personal-dashboard" "GOOGLE_CALENDAR_API_KEY" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "personal-dashboard" "CALENDAR_ICS_URL" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "personal-dashboard" "RUNPOD_API_KEY" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "personal-dashboard" "GEMINI_API_KEY" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "personal-dashboard" "JELLYFIN_API_KEY" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "personal-dashboard" "CLOUDFLARE_API_TOKEN" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "personal-dashboard" "CLOUDFLARE_ANALYTICS_TOKEN" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "personal-dashboard" "CLOUDFLARE_ZONE_ID" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "personal-dashboard" "PKMN_API_KEY" "PLACEHOLDER_COPY_FROM_NETCUP"
  create_identity "personal-dashboard-container" "$PROJECT_ID"
fi

echo ""
echo "========================================="
echo "7. ClipForge"
echo "========================================="
PROJECT_ID=$(create_project "ClipForge" "clip-forge") || true
if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "FAILED" ]; then
  push_secret "clip-forge" "DATABASE_URL" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "clip-forge" "REDIS_URL" "redis://redis:6379/0"
  push_secret "clip-forge" "OPENAI_API_KEY" "PLACEHOLDER_COPY_FROM_NETCUP"
  create_identity "clip-forge-container" "$PROJECT_ID"
fi

echo ""
echo "========================================="
echo "8. Open Claw Iron"
echo "========================================="
PROJECT_ID=$(create_project "IronClaw" "open-claw-iron") || true
if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "FAILED" ]; then
  push_secret "open-claw-iron" "DATABASE_URL" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "open-claw-iron" "GATEWAY_AUTH_TOKEN" "PLACEHOLDER_COPY_FROM_NETCUP"
  push_secret "open-claw-iron" "SECRETS_MASTER_KEY" "PLACEHOLDER_COPY_FROM_NETCUP"
  create_identity "open-claw-iron-container" "$PROJECT_ID"
fi

echo ""
echo "========================================="
echo "=== Migration Complete ==="
echo "========================================="
echo ""
echo "Credentials saved to: /tmp/infisical-tier1b-creds.txt"
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. SSH to Netcup and copy actual secret values from each service's .env"
echo "2. Update PLACEHOLDER secrets in Infisical with real values"
echo "3. For schedule: use the generated DB password (new deploy)"
echo "4. For grid-trading-bot: the generated DB password is for NEW deployments"
echo "   If service already has data, copy existing password from Netcup .env"
echo "5. Deploy each service with: docker compose up -d --build"
echo ""
cat /tmp/infisical-tier1b-creds.txt
