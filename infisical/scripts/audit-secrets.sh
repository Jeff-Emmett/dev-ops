#!/bin/bash
# Audit docker-compose files on Netcup for unmanaged secrets
# Usage: ./audit-secrets.sh [ssh-host]
#
# Scans all docker-compose.yml files under /opt/ for:
#   1. Hardcoded secrets in environment sections (passwords, keys, tokens)
#   2. .env files that still contain non-INFISICAL vars
#   3. Services missing INFISICAL_* env vars (not yet migrated)

set -euo pipefail

SSH_HOST="${1:-netcup}"
SEARCH_DIRS="/opt/websites /opt/apps /opt/erpnext /opt/discourse"

echo "=== Auditing secrets on ${SSH_HOST} ==="
echo ""

# Patterns that indicate hardcoded secrets
SECRET_PATTERNS='(PASSWORD|SECRET|TOKEN|API_KEY|PRIVATE_KEY|JWT_SECRET|ENCRYPTION_KEY|DB_PASS|REDIS_PASSWORD|SMTP_PASSWORD|CLIENT_SECRET)='

echo "--- [1/3] Hardcoded secrets in docker-compose files ---"
echo ""
ssh "$SSH_HOST" "
  for dir in ${SEARCH_DIRS}; do
    [ -d \"\$dir\" ] || continue
    find \"\$dir\" -maxdepth 3 -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' | while read -r f; do
      # Look for hardcoded secret-like values (not variable references)
      matches=\$(grep -nE '${SECRET_PATTERNS}' \"\$f\" 2>/dev/null | grep -v '\\\$' | grep -v 'INFISICAL_' || true)
      if [ -n \"\$matches\" ]; then
        echo \"FILE: \$f\"
        echo \"\$matches\" | sed 's/^/  /'
        echo ''
      fi
    done
  done
"

echo "--- [2/3] .env files with non-INFISICAL secrets ---"
echo ""
ssh "$SSH_HOST" "
  for dir in ${SEARCH_DIRS}; do
    [ -d \"\$dir\" ] || continue
    find \"\$dir\" -maxdepth 3 -name '.env' | while read -r f; do
      # Count non-INFISICAL, non-comment, non-empty lines
      non_infisical=\$(grep -v '^#' \"\$f\" | grep -v '^\$' | grep -v '^INFISICAL_' | grep -cE '${SECRET_PATTERNS}' || true)
      if [ \"\$non_infisical\" -gt 0 ]; then
        echo \"FILE: \$f (${non_infisical} unmanaged secret(s))\"
        grep -v '^#' \"\$f\" | grep -v '^\$' | grep -v '^INFISICAL_' | grep -E '${SECRET_PATTERNS}' | sed 's/=.*/=***/' | sed 's/^/  /'
        echo ''
      fi
    done
  done
"

echo "--- [3/3] Services without Infisical integration ---"
echo ""
ssh "$SSH_HOST" "
  for dir in ${SEARCH_DIRS}; do
    [ -d \"\$dir\" ] || continue
    find \"\$dir\" -maxdepth 3 -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' | while read -r f; do
      has_infisical=\$(grep -c 'INFISICAL_' \"\$f\" 2>/dev/null || echo 0)
      has_secrets=\$(grep -cE '${SECRET_PATTERNS}' \"\$f\" 2>/dev/null || echo 0)
      if [ \"\$has_infisical\" -eq 0 ] && [ \"\$has_secrets\" -gt 0 ]; then
        echo \"NOT MIGRATED: \$f (\${has_secrets} secret-like vars)\"
      fi
    done
  done
"

echo ""
echo "=== Audit complete ==="
