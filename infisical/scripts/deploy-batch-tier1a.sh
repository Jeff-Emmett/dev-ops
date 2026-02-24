#!/bin/bash
# Deploy 4 Tier 1a services to Netcup after Infisical migration
# Reads credentials from the file produced by migrate-batch-tier1a.sh
# Run locally — handles SCP + SSH to netcup-full
set -euo pipefail

NETCUP="netcup-full"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
log() { echo -e "${GREEN}[✓]${NC} $1"; }
step() { echo -e "\n${CYAN}=== $1 ===${NC}"; }
fail() { echo -e "${RED}[✗]${NC} $1"; }

# Find credentials file
CREDS_FILE="${1:-}"
if [ -z "$CREDS_FILE" ]; then
  CREDS_FILE=$(ls -t /tmp/infisical-batch-creds-*.txt 2>/dev/null | head -1)
fi
if [ -z "$CREDS_FILE" ] || [ ! -f "$CREDS_FILE" ]; then
  echo "Usage: $0 <path-to-credentials-file>"
  echo "  (or run migrate-batch-tier1a.sh first)"
  exit 1
fi
echo "Using credentials from: ${CREDS_FILE}"

# Parse credentials per service
get_cred() {
  local svc="$1" key="$2"
  sed -n "/^# ${svc}/,/^$/p" "$CREDS_FILE" | grep "^${key}=" | cut -d= -f2-
}

# ══════════════════════════════════════════════════════════════
# Deploy each service
# ══════════════════════════════════════════════════════════════

deploy_service() {
  local name="$1" path="$2" slug="$3"
  local cid csec

  step "Deploying: ${name}"

  cid=$(get_cred "$name" "INFISICAL_CLIENT_ID")
  csec=$(get_cred "$name" "INFISICAL_CLIENT_SECRET")

  if [ -z "$cid" ] || [ -z "$csec" ]; then
    fail "Missing credentials for ${name} in ${CREDS_FILE}"
    return 1
  fi

  # Backup existing .env
  ssh "$NETCUP" "cd '${path}' && [ -f .env ] && cp .env .env.pre-infisical || true" 2>/dev/null

  # Write new .env
  local env_content="INFISICAL_CLIENT_ID=${cid}\nINFISICAL_CLIENT_SECRET=${csec}"

  # Add compose-interpolation vars (DB passwords that postgres/redis containers need)
  local db_pass
  db_pass=$(get_cred "$name" "DB_PASSWORD" 2>/dev/null || true)
  [ -z "$db_pass" ] && db_pass=$(get_cred "$name" "POSTGRES_PASSWORD" 2>/dev/null || true)
  [ -n "$db_pass" ] && env_content="${env_content}\nDB_PASSWORD=${db_pass}\nPOSTGRES_PASSWORD=${db_pass}"

  # For mycofi, no DB password needed
  # For rchats, DB_PASSWORD is the compose var name

  ssh "$NETCUP" "printf '${env_content}\n' > '${path}/.env' && chmod 600 '${path}/.env'"
  log ".env written"

  # Pull code and rebuild
  ssh "$NETCUP" "cd '${path}' && git stash 2>/dev/null; git pull origin main" 2>&1 | tail -3
  log "Code pulled"

  ssh "$NETCUP" "cd '${path}' && docker compose up -d --build" 2>&1 | tail -5
  log "Containers rebuilt"

  # Wait and verify
  echo "  Waiting 12s for startup..."
  sleep 12

  # Find the main app container
  local container
  case "$name" in
    rcal-online) container="rcal-online" ;;
    rchats) container="rchats" ;;
    mycofi) container="mycofi-earth-website" ;;
    games-platform) container="games-backend" ;;
  esac

  local logs
  logs=$(ssh "$NETCUP" "docker logs '${container}' 2>&1 | grep '\\[infisical\\]' | tail -3" || true)
  if echo "$logs" | grep -q "Injected"; then
    log "Secret injection confirmed for ${name}!"
    echo "$logs" | sed 's/^/  /'
  else
    fail "Could not confirm injection. Check: ssh ${NETCUP} 'docker logs ${container} 2>&1 | tail -20'"
  fi
}

# ── Deploy all 4 services ────────────────────────────────────

deploy_service "rcal-online" "/opt/websites/rcal-online" "rcal-online"
deploy_service "rchats" "/opt/websites/rchats-online" "rchats"
deploy_service "mycofi" "/opt/websites/mycofi-earth-website" "mycofi"
deploy_service "games-platform" "/opt/apps/games-platform" "games-platform"

# ── Final summary ────────────────────────────────────────────
step "Done!"
echo ""
log "All 4 services deployed with Infisical secret injection"
echo ""
echo "Verify all containers:"
for svc in rcal-online rchats mycofi-earth-website games-backend games-worker; do
  echo "  ssh ${NETCUP} 'docker logs ${svc} 2>&1 | grep infisical'"
done
