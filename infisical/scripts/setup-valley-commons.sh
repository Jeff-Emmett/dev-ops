#!/bin/bash
# ============================================================================
# Valley-Commons → Infisical Migration Script
# ============================================================================
# Creates Infisical project, pushes secrets, creates machine identity,
# deploys entrypoint wrapper to Netcup, updates docker-compose and Dockerfile,
# and redeploys the valley-commons stack.
#
# STATUS: COMPLETED — secrets already migrated to Infisical (2026-02-25)
# Secret values removed from this file. If re-running, fetch from Infisical first.
#
# Usage:
#   ./setup-valley-commons.sh
#
# Prerequisites:
#   - Access to secrets.jeffemmett.com
#   - SSH access to Netcup (ssh netcup-full)
#   - Valley-commons repo at /home/jeffe/Github/valley-commons
#   - google-service-account.json at /home/jeffe/Github/valley-commons/
# ============================================================================

set -euo pipefail

INFISICAL_URL="https://secrets.jeffemmett.com"
API="${INFISICAL_URL}/api"
PROJECT_SLUG="valley-commons"
PROJECT_DISPLAY_NAME="Valley Commons"
NETCUP_HOST="netcup-full"
LOCAL_REPO="/home/jeffe/Github/valley-commons"
DEPLOY_PATH="/opt/websites/valley-commons"
GOOGLE_SA_JSON="${LOCAL_REPO}/google-service-account.json"

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
# Step 0: Validate prerequisites
# ============================================================================
step "Step 0: Validate prerequisites"

if [ ! -f "$GOOGLE_SA_JSON" ]; then
  err "google-service-account.json not found at $GOOGLE_SA_JSON"
  echo "This script needs the Google service account JSON to push as a secret."
  exit 1
fi
log "Found google-service-account.json"

# Validate it's valid JSON
if ! python3 -c "import json; json.load(open('${GOOGLE_SA_JSON}'))" 2>/dev/null; then
  err "google-service-account.json is not valid JSON"
  exit 1
fi
log "google-service-account.json is valid JSON"

# Check SSH connectivity
echo "Testing SSH connection to ${NETCUP_HOST}..."
if ! ssh -o ConnectTimeout=5 "$NETCUP_HOST" "echo ok" >/dev/null 2>&1; then
  err "Cannot connect to ${NETCUP_HOST} via SSH"
  exit 1
fi
log "SSH connection to ${NETCUP_HOST} working"

# Check deploy path exists
if ! ssh "$NETCUP_HOST" "[ -d '${DEPLOY_PATH}' ]" 2>/dev/null; then
  err "Deploy path ${DEPLOY_PATH} not found on ${NETCUP_HOST}"
  exit 1
fi
log "Deploy path verified: ${DEPLOY_PATH}"

# ============================================================================
# Step 1: Authenticate with Infisical
# ============================================================================
step "Step 1/10: Authenticate with Infisical"

CLAUDE_CLIENT_ID="0252dd42-d8e0-48cc-bb55-0b96a58907c6"

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
# Step 2: Deploy entrypoint wrapper to Netcup
# ============================================================================
step "Step 2/10: Deploy entrypoint wrapper to Netcup"

WRAPPER_SRC="/home/jeffe/Github/dev-ops/infisical/templates/entrypoint-wrapper.sh"

if [ ! -f "$WRAPPER_SRC" ]; then
  err "Wrapper not found at $WRAPPER_SRC"
  exit 1
fi

echo "Creating /opt/infisical/ on Netcup..."
ssh "$NETCUP_HOST" "mkdir -p /opt/infisical" || {
  err "Failed to create directory on Netcup. Ensure ssh ${NETCUP_HOST} works."
  exit 1
}

echo "Copying wrapper script..."
scp -q "$WRAPPER_SRC" "${NETCUP_HOST}:/opt/infisical/entrypoint-wrapper.sh"
ssh "$NETCUP_HOST" "chmod 755 /opt/infisical/entrypoint-wrapper.sh"
log "Wrapper deployed to /opt/infisical/entrypoint-wrapper.sh"

# ============================================================================
# Step 3: Check/Create Infisical project
# ============================================================================
step "Step 3/10: Create Infisical project '${PROJECT_SLUG}'"

# Check if project already exists
EXISTING=$(curl -sf "${API}/v1/workspace" \
  -H "Authorization: Bearer ${TOKEN}" 2>/dev/null | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for w in data.get('workspaces', []):
    if w.get('slug') == '${PROJECT_SLUG}':
        print(w['id'])
        break
" 2>/dev/null || true)

if [ -n "$EXISTING" ]; then
  PROJECT_ID="$EXISTING"
  log "Project '${PROJECT_SLUG}' already exists (ID: ${PROJECT_ID})"
else
  PROJECT_RESPONSE=$(curl -sf -X POST "${API}/v2/workspace" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"projectName\":\"${PROJECT_DISPLAY_NAME}\",\"slug\":\"${PROJECT_SLUG}\"}")

  PROJECT_ID=$(echo "$PROJECT_RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('workspace', d.get('project', {})).get('id', ''))
")

  if [ -z "$PROJECT_ID" ]; then
    err "Failed to create project. Response: $PROJECT_RESPONSE"
    exit 1
  fi
  log "Created project '${PROJECT_SLUG}' (ID: ${PROJECT_ID})"
fi

# ============================================================================
# Step 4: Push all 14 secrets to Infisical
# ============================================================================
step "Step 4/10: Push secrets to Infisical"

# Read the Google service account JSON into a variable (compact, single-line)
GOOGLE_SA_VALUE=$(python3 -c "import json; print(json.dumps(json.load(open('${GOOGLE_SA_JSON}'))))")

# Use Python to push all secrets
export TOKEN API PROJECT_SLUG GOOGLE_SA_VALUE
python3 << 'PYEOF'
import json, urllib.request, sys, os

token = os.environ["TOKEN"]
api = os.environ["API"]
slug = os.environ["PROJECT_SLUG"]
google_sa = os.environ["GOOGLE_SA_VALUE"]

# Define all 14 secrets — values already migrated to Infisical project 'valley-commons'
# To re-run, update values below or fetch from Infisical first
secrets = [
    {"secretKey": "ADMIN_API_KEY", "secretValue": "<from-infisical>"},
    {"secretKey": "SMTP_HOST", "secretValue": "mail.rmail.online"},
    {"secretKey": "SMTP_PORT", "secretValue": "587"},
    {"secretKey": "SMTP_USER", "secretValue": "noreply@jeffemmett.com"},
    {"secretKey": "SMTP_PASS", "secretValue": "<from-infisical>"},
    {"secretKey": "MOLLIE_API_KEY", "secretValue": "<from-infisical>"},
    {"secretKey": "POSTGRES_PASSWORD", "secretValue": "<from-infisical>"},
    {"secretKey": "DATABASE_URL", "secretValue": "<from-infisical>"},
    {"secretKey": "GOOGLE_SHEET_ID", "secretValue": "<from-infisical>"},
    {"secretKey": "GOOGLE_SERVICE_ACCOUNT", "secretValue": google_sa},
    {"secretKey": "ADMIN_EMAILS", "secretValue": "jeff@jeffemmett.com"},
    {"secretKey": "EMAIL_FROM", "secretValue": "Valley of the Commons <noreply@jeffemmett.com>"},
    {"secretKey": "BASE_URL", "secretValue": "https://valleyofthecommons.com"},
    {"secretKey": "NODE_ENV", "secretValue": "production"},
]

print(f"Pushing {len(secrets)} secrets to {slug}/prod...")

# Try batch create first
body = json.dumps({
    "projectSlug": slug,
    "environment": "prod",
    "secretPath": "/",
    "secrets": secrets
}).encode()

try:
    req = urllib.request.Request(
        f"{api}/v3/secrets/batch/raw",
        data=body, method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    )
    urllib.request.urlopen(req)
    print(f"[OK] Batch created {len(secrets)} secrets")
    sys.exit(0)
except Exception as e:
    print(f"[!] Batch create failed ({e}), trying individually...")

# Fall back to individual create/update
ok = 0
fail = 0
for s in secrets:
    key = s["secretKey"]
    val = s["secretValue"]
    # Truncate display for long values
    display_val = val[:40] + "..." if len(val) > 40 else val
    body = json.dumps({
        "projectSlug": slug, "environment": "prod",
        "secretPath": "/", "secretValue": val, "type": "shared"
    }).encode()

    try:
        req = urllib.request.Request(
            f"{api}/v3/secrets/raw/{key}", data=body, method="POST",
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        )
        urllib.request.urlopen(req)
        print(f"  OK: {key}")
        ok += 1
    except:
        try:
            body2 = json.dumps({
                "projectSlug": slug, "environment": "prod",
                "secretPath": "/", "secretValue": val
            }).encode()
            req = urllib.request.Request(
                f"{api}/v3/secrets/raw/{key}", data=body2, method="PATCH",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
            )
            urllib.request.urlopen(req)
            print(f"  UPDATED: {key}")
            ok += 1
        except Exception as e2:
            print(f"  FAILED: {key} - {e2}")
            fail += 1

print(f"\nResult: {ok} ok, {fail} failed out of {len(secrets)} secrets")
if fail > 0:
    sys.exit(1)
PYEOF

log "Secrets pushed to ${PROJECT_SLUG}/prod"

# ============================================================================
# Step 5: Create machine identity for valley-commons container
# ============================================================================
step "Step 5/10: Create machine identity 'valley-commons-deploy'"

ORG_ID="091129af-53a7-45e2-83b5-cda045203ab8"
IDENTITY_NAME="valley-commons-deploy"

# Check if identity already exists
EXISTING_IDENTITY=$(curl -sf "${API}/v1/organizations/${ORG_ID}/identity-memberships" \
  -H "Authorization: Bearer ${TOKEN}" 2>/dev/null | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data.get('identityMemberships', []):
    if m.get('identity', {}).get('name') == '${IDENTITY_NAME}':
        print(m['identity']['id'])
        break
" 2>/dev/null || true)

if [ -n "$EXISTING_IDENTITY" ]; then
  IDENTITY_ID="$EXISTING_IDENTITY"
  log "Identity '${IDENTITY_NAME}' already exists (ID: ${IDENTITY_ID})"

  echo "Creating new client secret for existing identity..."
  CLIENT_SECRET_RESP=$(curl -sf -X POST "${API}/v1/auth/universal-auth/identities/${IDENTITY_ID}/client-secrets" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"description\":\"${IDENTITY_NAME}\",\"numUsesLimit\":0,\"ttl\":0}")

  UA_RESP=$(curl -sf "${API}/v1/auth/universal-auth/identities/${IDENTITY_ID}" \
    -H "Authorization: Bearer ${TOKEN}")

  VC_CLIENT_ID=$(echo "$UA_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('identityUniversalAuth',{}).get('clientId',''))")
  VC_CLIENT_SECRET=$(echo "$CLIENT_SECRET_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('clientSecret',''))")
else
  IDENTITY_RESP=$(curl -sf -X POST "${API}/v1/identities" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${IDENTITY_NAME}\",\"role\":\"member\",\"organizationId\":\"${ORG_ID}\"}")

  IDENTITY_ID=$(echo "$IDENTITY_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('identity',{}).get('id',''))")

  if [ -z "$IDENTITY_ID" ]; then
    err "Failed to create identity. Response: $IDENTITY_RESP"
    exit 1
  fi
  log "Created identity '${IDENTITY_NAME}' (ID: ${IDENTITY_ID})"

  UA_RESP=$(curl -sf -X POST "${API}/v1/auth/universal-auth/identities/${IDENTITY_ID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"accessTokenTTL":0,"accessTokenMaxTTL":0,"accessTokenNumUsesLimit":0}')

  VC_CLIENT_ID=$(echo "$UA_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('identityUniversalAuth',{}).get('clientId',''))")

  CLIENT_SECRET_RESP=$(curl -sf -X POST "${API}/v1/auth/universal-auth/identities/${IDENTITY_ID}/client-secrets" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"description\":\"${IDENTITY_NAME}\",\"numUsesLimit\":0,\"ttl\":0}")

  VC_CLIENT_SECRET=$(echo "$CLIENT_SECRET_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('clientSecret',''))")

  # Grant project access
  curl -sf -X POST "${API}/v2/workspace/${PROJECT_ID}/identity-memberships/${IDENTITY_ID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"role":"viewer"}' > /dev/null 2>&1 || {
    warn "Could not grant project access (may need to do via UI)"
  }
fi

if [ -z "$VC_CLIENT_ID" ] || [ -z "$VC_CLIENT_SECRET" ]; then
  err "Failed to get client credentials"
  echo "Client ID: ${VC_CLIENT_ID:-MISSING}"
  echo "Client Secret: ${VC_CLIENT_SECRET:-MISSING}"
  exit 1
fi

log "Machine identity ready"
echo "  Client ID:     ${VC_CLIENT_ID}"
echo "  Client Secret: ${VC_CLIENT_SECRET:0:12}..."

# ============================================================================
# Step 6: Back up existing .env on Netcup
# ============================================================================
step "Step 6/10: Back up existing .env on Netcup"

echo "Backing up .env on Netcup..."
ssh "$NETCUP_HOST" "cd '${DEPLOY_PATH}' && [ -f .env ] && cp .env .env.pre-infisical || echo 'No .env to back up'"
log "Backed up .env as .env.pre-infisical (if it existed)"

# ============================================================================
# Step 7: Write new minimal .env
# ============================================================================
step "Step 7/10: Write new minimal .env on Netcup"

ssh "$NETCUP_HOST" "cat > '${DEPLOY_PATH}/.env'" << EOF
# Infisical credentials (for valley-commons app container)
INFISICAL_CLIENT_ID=${VC_CLIENT_ID}
INFISICAL_CLIENT_SECRET=${VC_CLIENT_SECRET}

# POSTGRES_PASSWORD needed for docker-compose interpolation in postgres service
POSTGRES_PASSWORD=\${POSTGRES_PASSWORD:-<set-from-infisical>}
EOF
ssh "$NETCUP_HOST" "chmod 600 '${DEPLOY_PATH}/.env'"
log "Created minimal .env with Infisical credentials + POSTGRES_PASSWORD"

# ============================================================================
# Step 8: Update docker-compose.yml on Netcup
# ============================================================================
step "Step 8/10: Update docker-compose.yml on Netcup"

echo "Patching docker-compose.yml..."
ssh "$NETCUP_HOST" "cd '${DEPLOY_PATH}' && python3 << 'INNEREOF'
import yaml, sys, copy

compose_file = 'docker-compose.yml'
try:
    with open(compose_file) as f:
        data = yaml.safe_load(f)
except Exception as e:
    print(f'ERROR: Could not read {compose_file}: {e}')
    sys.exit(1)

changed = False

# Find the main app service (typically 'app', 'web', or 'valley-commons')
app_service = None
for name in ['app', 'web', 'valley-commons', 'votc']:
    if name in data.get('services', {}):
        app_service = name
        break

# If not found, pick the first service that has a build context
if not app_service:
    for name, svc in data.get('services', {}).items():
        if 'build' in svc or 'image' not in svc:
            app_service = name
            break

if not app_service:
    print('ERROR: Could not identify the main app service in docker-compose.yml')
    print(f'Services found: {list(data.get(\"services\", {}).keys())}')
    sys.exit(1)

print(f'Identified app service: {app_service}')
svc = data['services'][app_service]

# 1. Remove google-service-account.json volume mount
if 'volumes' in svc:
    original_vols = svc['volumes'][:]
    svc['volumes'] = [v for v in svc['volumes'] if 'google-service-account' not in str(v)]
    if len(svc['volumes']) != len(original_vols):
        print('  Removed google-service-account.json volume mount')
        changed = True
    if not svc['volumes']:
        del svc['volumes']

# 2. Remove GOOGLE_SERVICE_ACCOUNT_FILE env var, add Infisical env vars
env = svc.get('environment', {})
# Handle both dict and list format
if isinstance(env, list):
    new_env = []
    for item in env:
        if isinstance(item, str) and item.startswith('GOOGLE_SERVICE_ACCOUNT_FILE'):
            print('  Removed GOOGLE_SERVICE_ACCOUNT_FILE env var')
            changed = True
            continue
        new_env.append(item)
    # Add Infisical env vars (list format)
    infisical_vars = [
        'INFISICAL_CLIENT_ID=\${INFISICAL_CLIENT_ID}',
        'INFISICAL_CLIENT_SECRET=\${INFISICAL_CLIENT_SECRET}',
        'INFISICAL_PROJECT_SLUG=valley-commons',
    ]
    for var in infisical_vars:
        key = var.split('=')[0]
        if not any(str(v).startswith(key + '=') for v in new_env):
            new_env.append(var)
            changed = True
    svc['environment'] = new_env
elif isinstance(env, dict):
    if 'GOOGLE_SERVICE_ACCOUNT_FILE' in env:
        del env['GOOGLE_SERVICE_ACCOUNT_FILE']
        print('  Removed GOOGLE_SERVICE_ACCOUNT_FILE env var')
        changed = True
    # Add Infisical env vars (dict format)
    if 'INFISICAL_CLIENT_ID' not in env:
        env['INFISICAL_CLIENT_ID'] = '\${INFISICAL_CLIENT_ID}'
        changed = True
    if 'INFISICAL_CLIENT_SECRET' not in env:
        env['INFISICAL_CLIENT_SECRET'] = '\${INFISICAL_CLIENT_SECRET}'
        changed = True
    if 'INFISICAL_PROJECT_SLUG' not in env:
        env['INFISICAL_PROJECT_SLUG'] = 'valley-commons'
        changed = True
    svc['environment'] = env
else:
    # No environment section yet, create one
    svc['environment'] = {
        'INFISICAL_CLIENT_ID': '\${INFISICAL_CLIENT_ID}',
        'INFISICAL_CLIENT_SECRET': '\${INFISICAL_CLIENT_SECRET}',
        'INFISICAL_PROJECT_SLUG': 'valley-commons',
    }
    changed = True

if changed:
    with open(compose_file, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
    print('  docker-compose.yml updated successfully')
else:
    print('  docker-compose.yml already up to date (no changes needed)')
INNEREOF
" || {
  warn "Python yaml module may not be available. Falling back to manual patch..."
  # Fallback: use sed-based approach
  ssh "$NETCUP_HOST" "cd '${DEPLOY_PATH}' && \
    sed -i '/google-service-account/d' docker-compose.yml && \
    sed -i '/GOOGLE_SERVICE_ACCOUNT_FILE/d' docker-compose.yml && \
    echo '  Patched docker-compose.yml with sed (manual review recommended)'"
}
log "docker-compose.yml updated"

# ============================================================================
# Step 9: Deploy entrypoint and update Dockerfile on Netcup
# ============================================================================
step "Step 9/10: Deploy entrypoint and update Dockerfile on Netcup"

# Copy the Node.js entrypoint template to the valley-commons repo on Netcup
ENTRYPOINT_SRC="/home/jeffe/Github/dev-ops/infisical/templates/entrypoint-node.sh"

if [ ! -f "$ENTRYPOINT_SRC" ]; then
  err "Entrypoint template not found at $ENTRYPOINT_SRC"
  exit 1
fi

echo "Copying entrypoint-node.sh to ${DEPLOY_PATH}/entrypoint.sh on Netcup..."
scp -q "$ENTRYPOINT_SRC" "${NETCUP_HOST}:${DEPLOY_PATH}/entrypoint.sh"
ssh "$NETCUP_HOST" "chmod +x '${DEPLOY_PATH}/entrypoint.sh'"
log "Entrypoint script deployed"

# Update Dockerfile to add entrypoint before CMD
echo "Patching Dockerfile..."
ssh "$NETCUP_HOST" "cd '${DEPLOY_PATH}' && python3 << 'INNEREOF'
import re

with open('Dockerfile') as f:
    content = f.read()

# Check if entrypoint is already added
if 'entrypoint.sh' in content:
    print('  Dockerfile already has entrypoint.sh, skipping')
else:
    # Insert COPY/RUN/ENTRYPOINT before the CMD line
    entrypoint_block = '''
# Infisical secret injection entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT [\"/entrypoint.sh\"]

'''
    # Find the CMD line and insert before it
    cmd_pattern = r'(^CMD\s+.*)$'
    match = re.search(cmd_pattern, content, re.MULTILINE)
    if match:
        insert_pos = match.start()
        content = content[:insert_pos] + entrypoint_block + content[insert_pos:]
        with open('Dockerfile', 'w') as f:
            f.write(content)
        print('  Dockerfile updated with entrypoint')
    else:
        # Append at the end if no CMD found
        content += entrypoint_block
        with open('Dockerfile', 'w') as f:
            f.write(content)
        print('  Dockerfile updated (appended entrypoint, no CMD found)')
INNEREOF
"
log "Dockerfile updated with Infisical entrypoint"

# Delete the plaintext google-service-account.json from Netcup
echo "Removing plaintext google-service-account.json from Netcup..."
ssh "$NETCUP_HOST" "[ -f '${DEPLOY_PATH}/google-service-account.json' ] && rm -f '${DEPLOY_PATH}/google-service-account.json' && echo 'Deleted' || echo 'File not found (already removed or never present)'"
log "Plaintext google-service-account.json removed from Netcup"

# ============================================================================
# Step 10: Rebuild and verify containers
# ============================================================================
step "Step 10/10: Rebuild and verify containers"

echo "Rebuilding containers..."
ssh "$NETCUP_HOST" "cd '${DEPLOY_PATH}' && docker compose up -d --build" || {
  err "Build failed. Check logs on Netcup:"
  echo "  ssh ${NETCUP_HOST} 'cd ${DEPLOY_PATH} && docker compose logs --tail=50'"
  exit 1
}
log "Containers rebuilt"

# Wait for startup
echo "Waiting 15s for containers to start..."
sleep 15

# Verify injection - try to find the app container name
echo "Checking secret injection..."
APP_CONTAINER=$(ssh "$NETCUP_HOST" "cd '${DEPLOY_PATH}' && docker compose ps --format '{{.Names}}' 2>/dev/null | head -1" || true)

if [ -n "$APP_CONTAINER" ]; then
  INJECT_LOG=$(ssh "$NETCUP_HOST" "docker logs '${APP_CONTAINER}' 2>&1 | grep '\[infisical\]' | tail -5" || true)

  if echo "$INJECT_LOG" | grep -q "Injected"; then
    log "Secret injection confirmed!"
    echo "$INJECT_LOG" | sed 's/^/  /'
  else
    warn "Could not confirm injection. Container logs:"
    ssh "$NETCUP_HOST" "docker logs '${APP_CONTAINER}' 2>&1 | tail -20" | sed 's/^/  /'
  fi
else
  warn "Could not determine container name. Check manually:"
  echo "  ssh ${NETCUP_HOST} 'cd ${DEPLOY_PATH} && docker compose logs --tail=20'"
fi

# ============================================================================
# Summary
# ============================================================================
step "Migration Complete"

echo ""
echo "Project:            ${PROJECT_SLUG}"
echo "Project ID:         ${PROJECT_ID}"
echo "Deploy path:        ${DEPLOY_PATH}"
echo "Identity:           ${IDENTITY_NAME}"
echo "Client ID:          ${VC_CLIENT_ID}"
echo "Client Secret:      ${VC_CLIENT_SECRET}"
echo ""
echo "Secrets pushed:     14 (including GOOGLE_SERVICE_ACCOUNT as JSON)"
echo ""
echo "Changes made on Netcup:"
echo "  - .env backed up as .env.pre-infisical"
echo "  - New minimal .env with Infisical credentials + POSTGRES_PASSWORD"
echo "  - docker-compose.yml updated (removed google-service-account volume/env)"
echo "  - Dockerfile updated with Infisical entrypoint"
echo "  - entrypoint.sh deployed from entrypoint-node.sh template"
echo "  - google-service-account.json removed from Netcup"
echo "  - Containers rebuilt and restarted"
echo ""
echo "SAVE THESE CREDENTIALS! The client secret cannot be retrieved later."
echo ""
echo "To verify:"
echo "  ssh ${NETCUP_HOST} 'cd ${DEPLOY_PATH} && docker compose logs --tail=30'"
echo "  ssh ${NETCUP_HOST} 'cd ${DEPLOY_PATH} && docker compose ps'"
echo ""
echo "To rollback:"
echo "  ssh ${NETCUP_HOST} 'cd ${DEPLOY_PATH} && cp .env.pre-infisical .env && docker compose up -d --build'"
