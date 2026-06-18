#!/usr/bin/env bash
# Commons Hub Directus token-signing KEY + SECRET. Sourced by ../rotate-signing-secret.sh
# ⚠ Rotating these logs out every Directus user + invalidates cached access
#   tokens. SCHEDULE it. Static API tokens (DB rows) survive.
INVENTORY_NAME="commons-hub-directus-app-secrets"
GEN='openssl rand -hex 32'
TARGETS=(
  "netcup|/opt/apps/commons-hub-directus/.env|KEY"
  "netcup|/opt/apps/commons-hub-directus/.env|SECRET"
)
RESTART=(
  "netcup|cd /opt/apps/commons-hub-directus && docker compose up -d --force-recreate"
)
VERIFY='ssh netcup-full "curl -sf http://localhost:8055/server/health" >/dev/null 2>&1 || true'
