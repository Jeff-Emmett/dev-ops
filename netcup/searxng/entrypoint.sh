#!/bin/sh
# Infisical secret injection entrypoint for SearXNG.
# Fetches secrets from Infisical (skipped if INFISICAL_CLIENT_ID is unset),
# then renders /etc/searxng/settings.yml.template into /etc/searxng/settings.yml
# with ${VAR} env-var substitution before exec'ing SearXNG.
# Optional env: INFISICAL_PROJECT_SLUG (default claude-ops),
#               INFISICAL_SECRET_PATH (default /searxng)

set -e

export INFISICAL_URL="${INFISICAL_URL:-http://infisical:8080}"
export INFISICAL_ENV="${INFISICAL_ENV:-prod}"
export INFISICAL_PROJECT_SLUG="${INFISICAL_PROJECT_SLUG:-claude-ops}"
export INFISICAL_SECRET_PATH="${INFISICAL_SECRET_PATH:-/searxng}"

if [ -n "$INFISICAL_CLIENT_ID" ] && [ -n "$INFISICAL_CLIENT_SECRET" ]; then
  echo "[infisical] Fetching secrets from ${INFISICAL_PROJECT_SLUG}/${INFISICAL_ENV}${INFISICAL_SECRET_PATH}..." >&2
  EXPORTS=$(python3 <<'PYEOF'
import urllib.request, json, os, sys
base = os.environ['INFISICAL_URL']
slug = os.environ['INFISICAL_PROJECT_SLUG']
env = os.environ['INFISICAL_ENV']
path = os.environ.get('INFISICAL_SECRET_PATH', '/')
try:
    data = json.dumps({'clientId': os.environ['INFISICAL_CLIENT_ID'], 'clientSecret': os.environ['INFISICAL_CLIENT_SECRET']}).encode()
    req = urllib.request.Request(f'{base}/api/v1/auth/universal-auth/login', data=data, headers={'Content-Type': 'application/json'})
    auth = json.loads(urllib.request.urlopen(req).read())
    token = auth.get('accessToken')
    if not token:
        print('[infisical] Auth failed', file=sys.stderr); sys.exit(1)
    req = urllib.request.Request(f'{base}/api/v3/secrets/raw?workspaceSlug={slug}&environment={env}&secretPath={path}&recursive=false')
    req.add_header('Authorization', f'Bearer {token}')
    secrets = json.loads(urllib.request.urlopen(req).read())
    if 'secrets' not in secrets:
        print('[infisical] No secrets returned', file=sys.stderr); sys.exit(1)
    for s in secrets['secrets']:
        key = s['secretKey']
        val = s['secretValue'].replace("'", "'\\''")
        print(f"export {key}='{val}'")
except Exception as e:
    print(f'[infisical] Error: {e}', file=sys.stderr); sys.exit(1)
PYEOF
  ) || {
    echo '[infisical] WARNING: Fetch failed, continuing with existing env vars' >&2
    EXPORTS=""
  }
  if echo "$EXPORTS" | grep -q '^export '; then
    COUNT=$(echo "$EXPORTS" | grep -c '^export ')
    eval "$EXPORTS"
    echo "[infisical] Injected ${COUNT} secrets" >&2
  fi
else
  echo '[infisical] No credentials set, using env vars from compose' >&2
fi

# Render settings.yml.template -> settings.yml with ${VAR} expansion.
# SearXNG's own entrypoint reads /etc/searxng/settings.yml; if we write it
# first, its config_handler sees it and uses it as-is.
if [ -f /etc/searxng/settings.yml.template ]; then
  echo '[searxng] Rendering /etc/searxng/settings.yml from template' >&2
  python3 -c "
import os, re, sys
with open('/etc/searxng/settings.yml.template') as f: tpl = f.read()
def sub(m):
    var = m.group(1)
    val = os.environ.get(var, '')
    if not val:
        print(f'[searxng] WARNING: env var {var} is empty', file=sys.stderr)
    return val
rendered = re.sub(r'\\\${([A-Z_][A-Z0-9_]*)}', sub, tpl)
with open('/etc/searxng/settings.yml', 'w') as f: f.write(rendered)
print('[searxng] Rendered settings.yml (' + str(len(rendered)) + ' bytes)', file=sys.stderr)
"
fi

exec "$@"
