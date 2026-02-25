#!/bin/sh
# Infisical secret injection entrypoint (Node.js)
# Fetches secrets from Infisical API and injects them as env vars before starting the app.
# Required env vars: INFISICAL_CLIENT_ID, INFISICAL_CLIENT_SECRET
# Optional: INFISICAL_PROJECT_SLUG, INFISICAL_ENV (default: prod),
#           INFISICAL_URL (default: http://infisical:8080)

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

# Use Node.js (already in the image) for reliable JSON parsing and HTTP calls
EXPORTS=$(node -e "
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

    // Output as shell-safe export statements
    for (const s of secrets.secrets) {
      // Single-quote the value to prevent shell expansion, escape existing single quotes
      const escaped = s.secretValue.replace(/'/g, \"'\\\\''\" );
      console.log('export ' + s.secretKey + \"='\" + escaped + \"'\");
    }
  } catch (e) { console.error('[infisical] Error:', e.message); process.exit(1); }
})();
" 2>&1) || {
  echo "[infisical] WARNING: Failed to fetch secrets, starting with existing env vars"
  exec "$@"
}

# Check if we got export statements or error messages
if echo "$EXPORTS" | grep -q "^export "; then
  COUNT=$(echo "$EXPORTS" | grep -c "^export ")
  eval "$EXPORTS"
  echo "[infisical] Injected ${COUNT} secrets"
else
  echo "[infisical] WARNING: $EXPORTS"
  echo "[infisical] Starting with existing env vars"
fi

exec "$@"
