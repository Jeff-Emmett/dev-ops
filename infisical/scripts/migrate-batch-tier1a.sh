#!/bin/bash
# Batch migrate 4 Tier 1 services to Infisical
# Services: rcal-online, rchats, mycofi, games-platform
#
# Run locally — handles Infisical API calls + SSH to Netcup for secret reads
# Prerequisites:
#   - Admin client credentials in ~/.secrets/infisical_admin_client_*
#   - SSH access to netcup-full (unrestricted)
#   - jq installed
set -euo pipefail

INFISICAL_URL="https://secrets.jeffemmett.com"
NETCUP="netcup-full"
API="${INFISICAL_URL}/api"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
log() { echo -e "${GREEN}[✓]${NC} $1"; }
step() { echo -e "\n${CYAN}=== $1 ===${NC}"; }
fail() { echo -e "${RED}[✗]${NC} $1"; }

# ── Auth ──────────────────────────────────────────────────────
step "Authenticate with Infisical admin"
ADMIN_CID=$(cat ~/.secrets/infisical_admin_client_id 2>/dev/null || true)
ADMIN_CSEC=$(cat ~/.secrets/infisical_admin_client_secret 2>/dev/null || true)
if [ -z "$ADMIN_CID" ] || [ -z "$ADMIN_CSEC" ]; then
  echo "Enter claude_admin Client ID:"
  read -r ADMIN_CID
  echo "Enter claude_admin Client Secret:"
  read -rs ADMIN_CSEC
  echo ""
fi

RESP=$(curl -sf --max-time 15 -X POST "${API}/v1/auth/universal-auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"${ADMIN_CID}\",\"clientSecret\":\"${ADMIN_CSEC}\"}")
TOKEN=$(echo "$RESP" | jq -r '.accessToken // empty')
if [ -z "$TOKEN" ]; then
  fail "Auth failed"
  echo "$RESP"
  exit 1
fi
log "Authenticated"
AUTH="Authorization: Bearer ${TOKEN}"

# ── Helper functions ──────────────────────────────────────────
create_project() {
  local slug="$1"
  echo "  Creating project '${slug}'..."

  local project
  project=$(curl -sf --max-time 15 -X POST "${API}/v2/workspace" \
    -H "${AUTH}" -H "Content-Type: application/json" \
    -d "{\"projectName\":\"${slug}\",\"slug\":\"${slug}\"}")

  local pid
  pid=$(echo "$project" | jq -r '.workspace.id // .project.id // empty')
  if [ -z "$pid" ]; then
    # Check if project already exists
    local existing
    existing=$(curl -sf --max-time 15 "${API}/v1/workspace" \
      -H "${AUTH}" | jq -r ".workspaces[] | select(.slug==\"${slug}\") | .id // empty")
    if [ -n "$existing" ]; then
      echo "  Project already exists (ID: ${existing})"
      echo "$existing"
      return 0
    fi
    fail "Failed to create project. Response: $project"
    return 1
  fi
  echo "  Project ID: ${pid}"
  echo "$pid"
}

push_secret() {
  local slug="$1" key="$2" val="$3"
  local json_val
  json_val=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$val")

  curl -sf --max-time 15 -X POST "${API}/v3/secrets/raw/${key}" \
    -H "${AUTH}" -H "Content-Type: application/json" \
    -d "{\"workspaceSlug\":\"${slug}\",\"environment\":\"prod\",\"secretPath\":\"/\",\"secretValue\":${json_val},\"type\":\"shared\"}" > /dev/null 2>&1 || \
  curl -sf --max-time 15 -X PATCH "${API}/v3/secrets/raw/${key}" \
    -H "${AUTH}" -H "Content-Type: application/json" \
    -d "{\"workspaceSlug\":\"${slug}\",\"environment\":\"prod\",\"secretPath\":\"/\",\"secretValue\":${json_val},\"type\":\"shared\"}" > /dev/null 2>&1 || true
}

create_identity() {
  local slug="$1" org_id="$2"
  echo "  Creating identity '${slug}-deploy'..."

  local identity
  identity=$(curl -sf --max-time 15 -X POST "${API}/v1/identities" \
    -H "${AUTH}" -H "Content-Type: application/json" \
    -d "{\"name\":\"${slug}-deploy\",\"role\":\"member\",\"organizationId\":\"${org_id}\"}")

  local iid
  iid=$(echo "$identity" | jq -r '.identity.id // empty')
  if [ -z "$iid" ]; then
    fail "Failed to create identity: $identity"
    return 1
  fi

  # Add universal auth
  local ua
  ua=$(curl -sf --max-time 15 -X POST "${API}/v1/auth/universal-auth/identities/${iid}" \
    -H "${AUTH}" -H "Content-Type: application/json" \
    -d '{"accessTokenTTL":0,"accessTokenMaxTTL":0,"accessTokenNumUsesLimit":0}')

  local cid
  cid=$(echo "$ua" | jq -r '.identityUniversalAuth.clientId // empty')

  # Create client secret
  local cs_resp
  cs_resp=$(curl -sf --max-time 15 -X POST "${API}/v1/auth/universal-auth/identities/${iid}/client-secrets" \
    -H "${AUTH}" -H "Content-Type: application/json" \
    -d '{"description":"deploy","numUsesLimit":0,"ttl":0}')

  local csec
  csec=$(echo "$cs_resp" | jq -r '.clientSecret // empty')

  if [ -z "$cid" ] || [ -z "$csec" ]; then
    fail "Failed to get credentials"
    return 1
  fi

  echo "${iid}|${cid}|${csec}"
}

grant_access() {
  local pid="$1" iid="$2"
  curl -sf --max-time 15 -X POST "${API}/v2/workspace/${pid}/identity-memberships/${iid}" \
    -H "${AUTH}" -H "Content-Type: application/json" \
    -d '{"role":"viewer"}' > /dev/null
}

# Get org ID
ORG_ID="091129af-53a7-45e2-83b5-cda045203ab8"

# ── Output file ───────────────────────────────────────────────
CREDS_FILE="/tmp/infisical-batch-creds-$(date +%Y%m%d-%H%M%S).txt"
echo "# Infisical batch migration credentials — $(date)" > "$CREDS_FILE"
chmod 600 "$CREDS_FILE"

# ══════════════════════════════════════════════════════════════
# Service 1: rcal-online
# ══════════════════════════════════════════════════════════════
step "1/4: rcal-online (1 secret)"

# Read secrets from Netcup
RCAL_PG_PASS=$(ssh "$NETCUP" "grep '^POSTGRES_PASSWORD=' /opt/websites/rcal-online/.env 2>/dev/null | cut -d= -f2-" || true)
if [ -z "$RCAL_PG_PASS" ]; then
  echo "  Could not read POSTGRES_PASSWORD from Netcup. Enter manually:"
  read -rs RCAL_PG_PASS
  echo ""
fi

# Create project
RCAL_PID=$(create_project "rcal-online")
sleep 0.3

# Push secrets
echo "  Pushing secrets..."
push_secret "rcal-online" "POSTGRES_PASSWORD" "$RCAL_PG_PASS"
push_secret "rcal-online" "DATABASE_URL" "postgresql://rcal:${RCAL_PG_PASS}@rcal-postgres:5432/rcal"
log "2 secrets pushed"

# Create identity
RCAL_IDENT=$(create_identity "rcal-online" "$ORG_ID")
RCAL_IID=$(echo "$RCAL_IDENT" | cut -d'|' -f1)
RCAL_CID=$(echo "$RCAL_IDENT" | cut -d'|' -f2)
RCAL_CSEC=$(echo "$RCAL_IDENT" | cut -d'|' -f3)
grant_access "$RCAL_PID" "$RCAL_IID"
log "Identity created and granted access"

echo "" >> "$CREDS_FILE"
echo "# rcal-online" >> "$CREDS_FILE"
echo "INFISICAL_CLIENT_ID=${RCAL_CID}" >> "$CREDS_FILE"
echo "INFISICAL_CLIENT_SECRET=${RCAL_CSEC}" >> "$CREDS_FILE"
echo "POSTGRES_PASSWORD=${RCAL_PG_PASS}" >> "$CREDS_FILE"

# ══════════════════════════════════════════════════════════════
# Service 2: rchats
# ══════════════════════════════════════════════════════════════
step "2/4: rchats (2 secrets)"

RCHATS_DB_PASS=$(ssh "$NETCUP" "grep '^DB_PASSWORD=' /opt/websites/rchats-online/.env 2>/dev/null | cut -d= -f2-" || true)
RCHATS_NEXTAUTH=$(ssh "$NETCUP" "grep '^NEXTAUTH_SECRET=' /opt/websites/rchats-online/.env 2>/dev/null | cut -d= -f2-" || true)
if [ -z "$RCHATS_DB_PASS" ]; then
  echo "  Could not read DB_PASSWORD from Netcup. Enter manually:"
  read -rs RCHATS_DB_PASS
  echo ""
fi
if [ -z "$RCHATS_NEXTAUTH" ]; then
  echo "  Could not read NEXTAUTH_SECRET from Netcup. Enter manually:"
  read -rs RCHATS_NEXTAUTH
  echo ""
fi

RCHATS_PID=$(create_project "rchats")
sleep 0.3

echo "  Pushing secrets..."
push_secret "rchats" "DB_PASSWORD" "$RCHATS_DB_PASS"
push_secret "rchats" "NEXTAUTH_SECRET" "$RCHATS_NEXTAUTH"
push_secret "rchats" "DATABASE_URL" "postgresql://rchats:${RCHATS_DB_PASS}@rchats-postgres:5432/rchats"
log "3 secrets pushed"

RCHATS_IDENT=$(create_identity "rchats" "$ORG_ID")
RCHATS_IID=$(echo "$RCHATS_IDENT" | cut -d'|' -f1)
RCHATS_CID=$(echo "$RCHATS_IDENT" | cut -d'|' -f2)
RCHATS_CSEC=$(echo "$RCHATS_IDENT" | cut -d'|' -f3)
grant_access "$RCHATS_PID" "$RCHATS_IID"
log "Identity created and granted access"

echo "" >> "$CREDS_FILE"
echo "# rchats" >> "$CREDS_FILE"
echo "INFISICAL_CLIENT_ID=${RCHATS_CID}" >> "$CREDS_FILE"
echo "INFISICAL_CLIENT_SECRET=${RCHATS_CSEC}" >> "$CREDS_FILE"
echo "DB_PASSWORD=${RCHATS_DB_PASS}" >> "$CREDS_FILE"

# ══════════════════════════════════════════════════════════════
# Service 3: mycofi
# ══════════════════════════════════════════════════════════════
step "3/4: mycofi (3 secrets)"

MYCOFI_GEMINI=$(ssh "$NETCUP" "grep '^GEMINI_API_KEY=' /opt/websites/mycofi-earth-website/.env 2>/dev/null | cut -d= -f2-" || true)
MYCOFI_RUNPOD=$(ssh "$NETCUP" "grep '^RUNPOD_API_KEY=' /opt/websites/mycofi-earth-website/.env 2>/dev/null | cut -d= -f2-" || true)
MYCOFI_FAL=$(ssh "$NETCUP" "grep '^FAL_KEY=' /opt/websites/mycofi-earth-website/.env 2>/dev/null | cut -d= -f2-" || true)

if [ -z "$MYCOFI_GEMINI" ]; then
  echo "  Could not read GEMINI_API_KEY from Netcup. Enter manually:"
  read -rs MYCOFI_GEMINI
  echo ""
fi
if [ -z "$MYCOFI_RUNPOD" ]; then
  echo "  Could not read RUNPOD_API_KEY from Netcup. Enter manually:"
  read -rs MYCOFI_RUNPOD
  echo ""
fi

MYCOFI_PID=$(create_project "mycofi")
sleep 0.3

echo "  Pushing secrets..."
push_secret "mycofi" "GEMINI_API_KEY" "$MYCOFI_GEMINI"
push_secret "mycofi" "RUNPOD_API_KEY" "$MYCOFI_RUNPOD"
[ -n "$MYCOFI_FAL" ] && push_secret "mycofi" "FAL_KEY" "$MYCOFI_FAL"
MYCOFI_COUNT=2
[ -n "$MYCOFI_FAL" ] && MYCOFI_COUNT=3
log "${MYCOFI_COUNT} secrets pushed"

MYCOFI_IDENT=$(create_identity "mycofi" "$ORG_ID")
MYCOFI_IID=$(echo "$MYCOFI_IDENT" | cut -d'|' -f1)
MYCOFI_CID=$(echo "$MYCOFI_IDENT" | cut -d'|' -f2)
MYCOFI_CSEC=$(echo "$MYCOFI_IDENT" | cut -d'|' -f3)
grant_access "$MYCOFI_PID" "$MYCOFI_IID"
log "Identity created and granted access"

echo "" >> "$CREDS_FILE"
echo "# mycofi" >> "$CREDS_FILE"
echo "INFISICAL_CLIENT_ID=${MYCOFI_CID}" >> "$CREDS_FILE"
echo "INFISICAL_CLIENT_SECRET=${MYCOFI_CSEC}" >> "$CREDS_FILE"

# ══════════════════════════════════════════════════════════════
# Service 4: games-platform
# ══════════════════════════════════════════════════════════════
step "4/4: games-platform (3 secrets)"

GAMES_DB_PASS=$(ssh "$NETCUP" "grep '^DB_PASSWORD=' /opt/apps/games-platform/.env 2>/dev/null | cut -d= -f2-" || true)
# Also check docker-compose for hardcoded default
if [ -z "$GAMES_DB_PASS" ]; then
  GAMES_DB_PASS=$(ssh "$NETCUP" "grep 'POSTGRES_PASSWORD' /opt/apps/games-platform/docker-compose.yml 2>/dev/null | grep -oP ':-\K[^}]+'" || true)
fi
if [ -z "$GAMES_DB_PASS" ]; then
  echo "  Could not read DB_PASSWORD from Netcup. Enter manually:"
  read -rs GAMES_DB_PASS
  echo ""
fi
if [ "$GAMES_DB_PASS" = "changeme123" ]; then
  echo -e "  ${RED}WARNING: DB password is 'changeme123' — rotate after migration!${NC}"
  echo "  (Cannot auto-rotate: existing PostgreSQL volume has the old password)"
  echo "  After deploy, run: ssh ${NETCUP} 'docker exec games-db psql -U games_user -d games_platform -c \"ALTER USER games_user PASSWORD '\\''<newpassword>'\\''\"'"
fi

GAMES_PID=$(create_project "games-platform")
sleep 0.3

echo "  Pushing secrets..."
push_secret "games-platform" "DB_PASSWORD" "$GAMES_DB_PASS"
push_secret "games-platform" "DATABASE_URL" "postgresql://games_user:${GAMES_DB_PASS}@postgres:5432/games_platform"
push_secret "games-platform" "REDIS_URL" "redis://redis:6379"
log "3 secrets pushed"

GAMES_IDENT=$(create_identity "games-platform" "$ORG_ID")
GAMES_IID=$(echo "$GAMES_IDENT" | cut -d'|' -f1)
GAMES_CID=$(echo "$GAMES_IDENT" | cut -d'|' -f2)
GAMES_CSEC=$(echo "$GAMES_IDENT" | cut -d'|' -f3)
grant_access "$GAMES_PID" "$GAMES_IID"
log "Identity created and granted access"

echo "" >> "$CREDS_FILE"
echo "# games-platform" >> "$CREDS_FILE"
echo "INFISICAL_CLIENT_ID=${GAMES_CID}" >> "$CREDS_FILE"
echo "INFISICAL_CLIENT_SECRET=${GAMES_CSEC}" >> "$CREDS_FILE"
echo "DB_PASSWORD=${GAMES_DB_PASS}" >> "$CREDS_FILE"

# ══════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════
step "Summary"
echo ""
log "All 4 projects created and secrets pushed!"
echo ""
echo "Credentials saved to: ${CREDS_FILE}"
echo ""
echo "Next: deploy each service. For each:"
echo "  1. SSH to netcup-full"
echo "  2. Write .env with INFISICAL_CLIENT_ID + INFISICAL_CLIENT_SECRET (+ DB password for compose)"
echo "  3. git pull && docker compose up -d --build"
echo ""
echo "Quick deploy commands:"
echo ""
for svc in rcal-online rchats mycofi games-platform; do
  case $svc in
    rcal-online)  path="/opt/websites/rcal-online" ;;
    rchats)       path="/opt/websites/rchats-online" ;;
    mycofi)       path="/opt/websites/mycofi-earth-website" ;;
    games-platform) path="/opt/apps/games-platform" ;;
  esac
  echo "  # ${svc}"
  echo "  ssh ${NETCUP} \"cd ${path} && git stash 2>/dev/null; git pull origin main && docker compose up -d --build\""
  echo ""
done
