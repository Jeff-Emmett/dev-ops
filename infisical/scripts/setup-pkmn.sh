#!/bin/bash
# ============================================================================
# PKMN → Infisical Migration Script
# ============================================================================
# Creates Infisical project, pushes secrets from .env.prod, creates machine
# identity, deploys wrapper to Netcup, and deploys the updated PKMN stack.
#
# Usage:
#   ./setup-pkmn.sh
#
# Prerequisites:
#   - Access to secrets.jeffemmett.com
#   - SSH access to Netcup (ssh netcup-full)
#   - PKMN repo at /home/jeffe/Github/personal-knowledge-management-network
# ============================================================================

set -euo pipefail

INFISICAL_URL="https://secrets.jeffemmett.com"
API="${INFISICAL_URL}/api"
PROJECT_SLUG="pkmn-app"
NETCUP_HOST="netcup-full"
PKMN_LOCAL="/home/jeffe/Github/personal-knowledge-management-network"
PKMN_ENV_PROD="${PKMN_LOCAL}/.env.prod"
PKMN_DEPLOY_PATH=""  # discovered during script

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
step() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

# ============================================================================
# Step 0: Validate .env.prod exists
# ============================================================================
if [ ! -f "$PKMN_ENV_PROD" ]; then
  err ".env.prod not found at $PKMN_ENV_PROD"
  echo "This script reads secrets from the existing .env.prod file."
  exit 1
fi
log "Found .env.prod at $PKMN_ENV_PROD"

# ============================================================================
# Step 1: Authenticate with Infisical
# ============================================================================
step "Step 1/7: Authenticate with Infisical"

CLAUDE_CLIENT_ID="106c8eea-98e7-43c0-9f43-2dec375ad090"

echo "Enter the claude-agent Client Secret (from Infisical UI → Machine Identities → claude-agent):"
read -rs CLAUDE_CLIENT_SECRET
echo ""

if [ -z "$CLAUDE_CLIENT_SECRET" ]; then
  err "Client secret cannot be empty"
  exit 1
fi

echo "Authenticating..."
AUTH_RESPONSE=$(curl -sf -X POST "${API}/v1/auth/universal-auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"${CLAUDE_CLIENT_ID}\",\"clientSecret\":\"${CLAUDE_CLIENT_SECRET}\"}" 2>&1) || {
  err "Authentication failed. Check your client secret."
  exit 1
}

TOKEN=$(echo "$AUTH_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))")
if [ -z "$TOKEN" ]; then
  err "No access token returned. Response: $AUTH_RESPONSE"
  exit 1
fi
log "Authenticated with Infisical"

# ============================================================================
# Step 2: Deploy wrapper to Netcup
# ============================================================================
step "Step 2/7: Deploy entrypoint wrapper to Netcup"

WRAPPER_SRC="/home/jeffe/Github/dev-ops/infisical/templates/entrypoint-wrapper.sh"

if [ ! -f "$WRAPPER_SRC" ]; then
  err "Wrapper not found at $WRAPPER_SRC"
  exit 1
fi

echo "Creating /opt/infisical/ on Netcup..."
ssh "$NETCUP_HOST" "mkdir -p /opt/infisical" || {
  err "Failed to create directory on Netcup. Ensure ssh netcup-full works."
  exit 1
}

echo "Copying wrapper script..."
scp -q "$WRAPPER_SRC" "${NETCUP_HOST}:/opt/infisical/entrypoint-wrapper.sh"
ssh "$NETCUP_HOST" "chmod 755 /opt/infisical/entrypoint-wrapper.sh"
log "Wrapper deployed to /opt/infisical/entrypoint-wrapper.sh"

# ============================================================================
# Step 3: Find PKMN deploy path on Netcup
# ============================================================================
step "Step 3/7: Locate PKMN deployment on Netcup"

for path in /opt/apps/personal-knowledge-management-network /opt/websites/personal-knowledge-management-network /opt/pkmn; do
  if ssh "$NETCUP_HOST" "[ -d '$path' ]" 2>/dev/null; then
    PKMN_DEPLOY_PATH="$path"
    break
  fi
done

if [ -z "$PKMN_DEPLOY_PATH" ]; then
  warn "Could not auto-detect PKMN deploy path on Netcup"
  echo "Enter the deployment path (e.g., /opt/apps/personal-knowledge-management-network):"
  read -r PKMN_DEPLOY_PATH
fi
log "PKMN deploy path: $PKMN_DEPLOY_PATH"

# ============================================================================
# Step 4: Create Infisical project
# ============================================================================
step "Step 4/7: Create Infisical project '${PROJECT_SLUG}'"

# Check if project already exists
echo "Checking for existing project..."
WORKSPACE_LIST=$(curl -sf --max-time 15 "${API}/v1/workspace" \
  -H "Authorization: Bearer ${TOKEN}" 2>&1) || WORKSPACE_LIST=""

EXISTING=""
if [ -n "$WORKSPACE_LIST" ]; then
  EXISTING=$(echo "$WORKSPACE_LIST" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for w in data.get('workspaces', []):
        if w.get('slug') == '${PROJECT_SLUG}':
            print(w['id'])
            break
except: pass
" 2>/dev/null) || true
fi

if [ -n "$EXISTING" ]; then
  PROJECT_ID="$EXISTING"
  log "Project '${PROJECT_SLUG}' already exists (ID: ${PROJECT_ID})"
else
  echo "Creating new project..."
  PROJECT_RESPONSE=$(curl -sf --max-time 15 -X POST "${API}/v2/workspace" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"projectName\":\"PKMN\",\"slug\":\"${PROJECT_SLUG}\"}" 2>&1) || {
    err "Failed to create project. Response: $PROJECT_RESPONSE"
    exit 1
  }

  PROJECT_ID=$(echo "$PROJECT_RESPONSE" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('workspace', d.get('project', {})).get('id', ''))
except: pass
" 2>/dev/null) || true

  if [ -z "$PROJECT_ID" ]; then
    err "Failed to create project. Response: $PROJECT_RESPONSE"
    exit 1
  fi
  log "Created project '${PROJECT_SLUG}' (ID: ${PROJECT_ID})"
fi

# ============================================================================
# Step 5: Read .env.prod and push secrets to Infisical
# ============================================================================
step "Step 5/7: Push secrets from .env.prod to Infisical"

# Use Python to read .env.prod, parse, and push via API
python3 << 'PYEOF'
import json, urllib.request, sys, os

env_file = os.environ.get("PKMN_ENV_PROD", "")
token = os.environ.get("TOKEN", "")
api = os.environ.get("API", "")
slug = os.environ.get("PROJECT_SLUG", "")

# Parse .env.prod
secrets = []
with open(env_file) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if '=' not in line:
            continue
        key, _, val = line.partition('=')
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        if key.startswith('INFISICAL_'):
            continue
        secrets.append({'secretKey': key, 'secretValue': val})

if not secrets:
    print('[!] No secrets found in .env.prod')
    sys.exit(1)

print(f'Found {len(secrets)} secrets in .env.prod')

# Try batch create first
body = json.dumps({
    'projectSlug': slug,
    'environment': 'prod',
    'secretPath': '/',
    'secrets': secrets
}).encode()

try:
    req = urllib.request.Request(
        f'{api}/v3/secrets/batch/raw',
        data=body, method='POST',
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
    )
    urllib.request.urlopen(req)
    print(f'[OK] Batch created {len(secrets)} secrets')
    sys.exit(0)
except Exception as e:
    print(f'[!] Batch create failed ({e}), trying individually...')

# Fall back to individual create/update
ok = 0
fail = 0
for s in secrets:
    key = s['secretKey']
    val = s['secretValue']
    body = json.dumps({
        'projectSlug': slug, 'environment': 'prod',
        'secretPath': '/', 'secretValue': val, 'type': 'shared'
    }).encode()

    try:
        req = urllib.request.Request(
            f'{api}/v3/secrets/raw/{key}', data=body, method='POST',
            headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
        )
        urllib.request.urlopen(req)
        print(f'  OK: {key}')
        ok += 1
    except:
        try:
            body2 = json.dumps({
                'projectSlug': slug, 'environment': 'prod',
                'secretPath': '/', 'secretValue': val
            }).encode()
            req = urllib.request.Request(
                f'{api}/v3/secrets/raw/{key}', data=body2, method='PATCH',
                headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
            )
            urllib.request.urlopen(req)
            print(f'  UPDATED: {key}')
            ok += 1
        except Exception as e2:
            print(f'  FAILED: {key} - {e2}')
            fail += 1

print(f'\nResult: {ok} ok, {fail} failed')
if fail > 0:
    sys.exit(1)
PYEOF

log "Secrets pushed to ${PROJECT_SLUG}/prod"

# ============================================================================
# Step 6: Create machine identity for PKMN container
# ============================================================================
step "Step 6/7: Create machine identity"

ORG_ID="091129af-53a7-45e2-83b5-cda045203ab8"

# Check if identity already exists
echo "Checking for existing identity..."
IDENTITY_LIST=$(curl -sf --max-time 15 "${API}/v1/organizations/${ORG_ID}/identity-memberships" \
  -H "Authorization: Bearer ${TOKEN}" 2>&1) || IDENTITY_LIST=""

EXISTING_IDENTITY=""
if [ -n "$IDENTITY_LIST" ]; then
  EXISTING_IDENTITY=$(echo "$IDENTITY_LIST" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for m in data.get('identityMemberships', []):
        if m.get('identity', {}).get('name') == 'pkmn-deploy':
            print(m['identity']['id'])
            break
except: pass
" 2>/dev/null) || true
fi

if [ -n "$EXISTING_IDENTITY" ]; then
  IDENTITY_ID="$EXISTING_IDENTITY"
  log "Identity 'pkmn-deploy' already exists (ID: ${IDENTITY_ID})"

  echo "Creating new client secret for existing identity..."
  CLIENT_SECRET_RESP=$(curl -sf -X POST "${API}/v1/auth/universal-auth/identities/${IDENTITY_ID}/client-secrets" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"description":"pkmn-deploy","numUsesLimit":0,"ttl":0}')

  UA_RESP=$(curl -sf "${API}/v1/auth/universal-auth/identities/${IDENTITY_ID}" \
    -H "Authorization: Bearer ${TOKEN}")

  PKMN_CLIENT_ID=$(echo "$UA_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('identityUniversalAuth',{}).get('clientId',''))")
  PKMN_CLIENT_SECRET=$(echo "$CLIENT_SECRET_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('clientSecret',''))")
else
  IDENTITY_RESP=$(curl -sf -X POST "${API}/v1/identities" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"pkmn-deploy\",\"role\":\"member\",\"organizationId\":\"${ORG_ID}\"}")

  IDENTITY_ID=$(echo "$IDENTITY_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('identity',{}).get('id',''))")

  if [ -z "$IDENTITY_ID" ]; then
    err "Failed to create identity. Response: $IDENTITY_RESP"
    exit 1
  fi
  log "Created identity 'pkmn-deploy' (ID: ${IDENTITY_ID})"

  UA_RESP=$(curl -sf -X POST "${API}/v1/auth/universal-auth/identities/${IDENTITY_ID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"accessTokenTTL":0,"accessTokenMaxTTL":0,"accessTokenNumUsesLimit":0}')

  PKMN_CLIENT_ID=$(echo "$UA_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('identityUniversalAuth',{}).get('clientId',''))")

  CLIENT_SECRET_RESP=$(curl -sf -X POST "${API}/v1/auth/universal-auth/identities/${IDENTITY_ID}/client-secrets" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"description":"pkmn-deploy","numUsesLimit":0,"ttl":0}')

  PKMN_CLIENT_SECRET=$(echo "$CLIENT_SECRET_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('clientSecret',''))")

  curl -sf -X POST "${API}/v2/workspace/${PROJECT_ID}/identity-memberships/${IDENTITY_ID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"role":"viewer"}' > /dev/null 2>&1 || {
    warn "Could not grant project access (may need to do via UI)"
  }
fi

if [ -z "$PKMN_CLIENT_ID" ] || [ -z "$PKMN_CLIENT_SECRET" ]; then
  err "Failed to get client credentials"
  echo "Client ID: ${PKMN_CLIENT_ID:-MISSING}"
  echo "Client Secret: ${PKMN_CLIENT_SECRET:-MISSING}"
  exit 1
fi

log "Machine identity ready"
echo "  Client ID:     ${PKMN_CLIENT_ID}"
echo "  Client Secret: ${PKMN_CLIENT_SECRET:0:12}..."

# ============================================================================
# Step 7: Deploy to Netcup
# ============================================================================
step "Step 7/7: Deploy PKMN to Netcup"

# Read DB_PASSWORD and REDIS_PASSWORD from .env.prod for the minimal .env
DB_PASSWORD=$(grep -E '^DB_PASSWORD=' "$PKMN_ENV_PROD" | head -1 | cut -d= -f2-)
REDIS_PASSWORD=$(grep -E '^REDIS_PASSWORD=' "$PKMN_ENV_PROD" | head -1 | cut -d= -f2-)

if [ -z "$DB_PASSWORD" ] || [ -z "$REDIS_PASSWORD" ]; then
  err "Could not read DB_PASSWORD or REDIS_PASSWORD from .env.prod"
  exit 1
fi

# Back up existing .env.prod
echo "Backing up .env.prod on Netcup..."
ssh "$NETCUP_HOST" "cd '${PKMN_DEPLOY_PATH}' && [ -f .env.prod ] && cp .env.prod .env.prod.pre-infisical || true"
log "Backed up .env.prod"

# Create new minimal .env (uses heredoc with variable expansion)
echo "Writing new .env..."
ssh "$NETCUP_HOST" "cat > '${PKMN_DEPLOY_PATH}/.env'" << EOF
# Infisical credentials (backend, celery-worker, celery-beat)
INFISICAL_CLIENT_ID=${PKMN_CLIENT_ID}
INFISICAL_CLIENT_SECRET=${PKMN_CLIENT_SECRET}

# DB/Redis passwords (needed for docker-compose interpolation in postgres/redis services)
DB_PASSWORD=${DB_PASSWORD}
REDIS_PASSWORD=${REDIS_PASSWORD}
EOF
ssh "$NETCUP_HOST" "chmod 600 '${PKMN_DEPLOY_PATH}/.env'"
log "Created minimal .env"

# Pull latest code and rebuild
echo "Pulling latest code..."
ssh "$NETCUP_HOST" "cd '${PKMN_DEPLOY_PATH}' && git stash 2>/dev/null; git pull origin main"
log "Code updated"

echo "Rebuilding containers..."
ssh "$NETCUP_HOST" "cd '${PKMN_DEPLOY_PATH}' && docker compose -f docker-compose.prod.yml up -d --build" || {
  err "Build failed. Check logs on Netcup."
  exit 1
}
log "Containers rebuilt"

# Wait for startup
echo "Waiting 15s for containers to start..."
sleep 15

# Verify
echo "Checking injection..."
INJECT_LOG=$(ssh "$NETCUP_HOST" "docker logs pkmn-api 2>&1 | grep '\[infisical\]' | tail -5")

if echo "$INJECT_LOG" | grep -q "Injected"; then
  log "Secret injection confirmed!"
  echo "$INJECT_LOG" | sed 's/^/  /'
else
  warn "Could not confirm injection. Container logs:"
  ssh "$NETCUP_HOST" "docker logs pkmn-api 2>&1 | tail -20" | sed 's/^/  /'
fi

# ============================================================================
# Summary
# ============================================================================
step "Migration Complete"

echo ""
echo "Project:          ${PROJECT_SLUG}"
echo "Deploy path:      ${PKMN_DEPLOY_PATH}"
echo "Client ID:        ${PKMN_CLIENT_ID}"
echo "Client Secret:    ${PKMN_CLIENT_SECRET}"
echo ""
echo "Save these credentials! The client secret cannot be retrieved later."
echo ""
echo "To verify:"
echo "  ssh ${NETCUP_HOST} 'docker logs pkmn-api 2>&1 | grep infisical'"
echo "  ssh ${NETCUP_HOST} 'docker logs pkmn-celery-worker 2>&1 | grep infisical'"
echo "  ssh ${NETCUP_HOST} 'docker logs pkmn-celery-beat 2>&1 | grep infisical'"
