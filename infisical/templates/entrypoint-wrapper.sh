#!/bin/sh
# Infisical secret injection wrapper for third-party images
# Volume-mount this file and override entrypoint in docker-compose.yml.
# Auto-detects available runtime: node > python3 > curl+jq
#
# Usage in docker-compose.yml:
#   volumes:
#     - /opt/infisical/entrypoint-wrapper.sh:/infisical-entrypoint.sh:ro
#   entrypoint: ["/infisical-entrypoint.sh"]
#   command: ["original-startup-command", "args"]
#
# Required env vars: INFISICAL_CLIENT_ID, INFISICAL_CLIENT_SECRET, INFISICAL_PROJECT_SLUG
# Optional: INFISICAL_ENV (default: prod), INFISICAL_URL (default: http://infisical:8080)

set -e

export INFISICAL_URL="${INFISICAL_URL:-http://infisical:8080}"
export INFISICAL_ENV="${INFISICAL_ENV:-prod}"

if [ -z "$INFISICAL_PROJECT_SLUG" ]; then
  echo "[infisical-wrapper] ERROR: INFISICAL_PROJECT_SLUG must be set"
  exit 1
fi

if [ -z "$INFISICAL_CLIENT_ID" ] || [ -z "$INFISICAL_CLIENT_SECRET" ]; then
  echo "[infisical-wrapper] No credentials set, starting without secret injection"
  exec "$@"
fi

echo "[infisical-wrapper] Fetching secrets from ${INFISICAL_PROJECT_SLUG}/${INFISICAL_ENV}..."

# Auto-detect available runtime
RUNTIME=""
if command -v node >/dev/null 2>&1; then
  RUNTIME="node"
elif command -v python3 >/dev/null 2>&1; then
  RUNTIME="python3"
elif command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  RUNTIME="curl"
else
  echo "[infisical-wrapper] WARNING: No supported runtime (node/python3/curl+jq), starting without secrets"
  exec "$@"
fi

echo "[infisical-wrapper] Using runtime: ${RUNTIME}"

fetch_secrets_node() {
  node -e "
const http = require('http');
const https = require('https');
const url = new URL(process.env.INFISICAL_URL);
const client = url.protocol === 'https:' ? https : http;

const post = (path, body) => new Promise((resolve, reject) => {
  const data = JSON.stringify(body);
  const req = client.request({ hostname: url.hostname, port: url.port, path, method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Content-Length': data.length }
  }, res => { let d = ''; res.on('data', c => d += c); res.on('end', () => resolve(JSON.parse(d))); });
  req.on('error', reject);
  req.end(data);
});

const get = (path, token) => new Promise((resolve, reject) => {
  const req = client.request({ hostname: url.hostname, port: url.port, path, method: 'GET',
    headers: { 'Authorization': 'Bearer ' + token }
  }, res => { let d = ''; res.on('data', c => d += c); res.on('end', () => resolve(JSON.parse(d))); });
  req.on('error', reject);
  req.end();
});

(async () => {
  try {
    const auth = await post('/api/v1/auth/universal-auth/login', {
      clientId: process.env.INFISICAL_CLIENT_ID,
      clientSecret: process.env.INFISICAL_CLIENT_SECRET
    });
    if (!auth.accessToken) { console.error('[infisical] Auth failed'); process.exit(1); }

    const slug = process.env.INFISICAL_PROJECT_SLUG;
    const env = process.env.INFISICAL_ENV;
    const secrets = await get('/api/v3/secrets/raw?workspaceSlug=' + slug + '&environment=' + env + '&secretPath=/&recursive=true', auth.accessToken);
    if (!secrets.secrets) { console.error('[infisical] No secrets returned'); process.exit(1); }

    for (const s of secrets.secrets) {
      const escaped = s.secretValue.replace(/'/g, \"'\\\\''\" );
      console.log('export ' + s.secretKey + \"='\" + escaped + \"'\");
    }
  } catch (e) { console.error('[infisical] Error:', e.message); process.exit(1); }
})();
"
}

fetch_secrets_python() {
  python3 -c "
import urllib.request, json, os, sys

base = os.environ['INFISICAL_URL']
slug = os.environ['INFISICAL_PROJECT_SLUG']
env = os.environ['INFISICAL_ENV']

try:
    data = json.dumps({'clientId': os.environ['INFISICAL_CLIENT_ID'], 'clientSecret': os.environ['INFISICAL_CLIENT_SECRET']}).encode()
    req = urllib.request.Request(f'{base}/api/v1/auth/universal-auth/login', data=data, headers={'Content-Type': 'application/json'})
    auth = json.loads(urllib.request.urlopen(req).read())
    token = auth.get('accessToken')
    if not token:
        print('[infisical] Auth failed', file=sys.stderr)
        sys.exit(1)

    req = urllib.request.Request(f'{base}/api/v3/secrets/raw?workspaceSlug={slug}&environment={env}&secretPath=/&recursive=true')
    req.add_header('Authorization', f'Bearer {token}')
    secrets = json.loads(urllib.request.urlopen(req).read())

    if 'secrets' not in secrets:
        print('[infisical] No secrets returned', file=sys.stderr)
        sys.exit(1)

    for s in secrets['secrets']:
        key = s['secretKey']
        val = s['secretValue'].replace(\"'\", \"'\\\\'\")
        print(f\"export {key}='{val}'\")
except Exception as e:
    print(f'[infisical] Error: {e}', file=sys.stderr)
    sys.exit(1)
"
}

fetch_secrets_curl() {
  # Authenticate
  AUTH_RESPONSE=$(curl -sf -X POST "${INFISICAL_URL}/api/v1/auth/universal-auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"clientId\":\"${INFISICAL_CLIENT_ID}\",\"clientSecret\":\"${INFISICAL_CLIENT_SECRET}\"}")

  TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.accessToken // empty')
  if [ -z "$TOKEN" ]; then
    echo "[infisical] Auth failed" >&2
    return 1
  fi

  # Fetch secrets
  SECRETS_RESPONSE=$(curl -sf -X GET \
    "${INFISICAL_URL}/api/v3/secrets/raw?workspaceSlug=${INFISICAL_PROJECT_SLUG}&environment=${INFISICAL_ENV}&secretPath=/&recursive=true" \
    -H "Authorization: Bearer ${TOKEN}")

  # Parse and output export statements
  echo "$SECRETS_RESPONSE" | jq -r '.secrets[] | "export \(.secretKey)='"'"'" + (.secretValue | gsub("'"'"'"; "'"'"'\\'"'"''"'"'")) + "'"'"'"'
}

# Fetch secrets using detected runtime
EXPORTS=$(case "$RUNTIME" in
  node)    fetch_secrets_node ;;
  python3) fetch_secrets_python ;;
  curl)    fetch_secrets_curl ;;
esac 2>&1) || {
  echo "[infisical-wrapper] WARNING: Failed to fetch secrets, starting with existing env vars"
  exec "$@"
}

# Check if we got export statements or error messages
if echo "$EXPORTS" | grep -q "^export "; then
  COUNT=$(echo "$EXPORTS" | grep -c "^export ")
  eval "$EXPORTS"
  echo "[infisical-wrapper] Injected ${COUNT} secrets via ${RUNTIME}"
else
  echo "[infisical-wrapper] WARNING: $EXPORTS"
  echo "[infisical-wrapper] Starting with existing env vars"
fi

exec "$@"
