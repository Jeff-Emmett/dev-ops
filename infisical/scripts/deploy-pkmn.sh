#!/bin/bash
# Deploy PKMN Infisical migration to Netcup
# Run locally — handles SCP + SSH to netcup-full
set -euo pipefail

NETCUP="netcup-full"
PKMN_PATH="/opt/apps/pkmn"
WRAPPER_SRC="/home/jeffe/Github/dev-ops/infisical/templates/entrypoint-wrapper.sh"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'
log() { echo -e "${GREEN}[✓]${NC} $1"; }
step() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

step "1/5: Deploy wrapper to /opt/infisical/"
ssh "$NETCUP" "mkdir -p /opt/infisical"
scp -q "$WRAPPER_SRC" "${NETCUP}:/opt/infisical/entrypoint-wrapper.sh"
ssh "$NETCUP" "chmod 755 /opt/infisical/entrypoint-wrapper.sh"
log "Wrapper deployed"

step "2/5: Back up existing .env.prod"
ssh "$NETCUP" "cd '${PKMN_PATH}' && [ -f .env.prod ] && cp .env.prod .env.prod.pre-infisical || true"
log "Backup done"

step "3/5: Write minimal .env"
# Read credentials — expects .env.pkmn-deploy in this script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_DEPLOY="${SCRIPT_DIR}/.env.pkmn-deploy"
if [ ! -f "$ENV_DEPLOY" ]; then
  echo "Enter INFISICAL_CLIENT_ID for pkmn-deploy:"
  read -r PKMN_CID
  echo "Enter INFISICAL_CLIENT_SECRET for pkmn-deploy:"
  read -rs PKMN_CSEC
  echo ""
  # Read DB/Redis passwords from local .env.prod
  PKMN_LOCAL="/home/jeffe/Github/personal-knowledge-management-network/.env.prod"
  DB_PASS=$(grep '^DB_PASSWORD=' "$PKMN_LOCAL" | cut -d= -f2-)
  REDIS_PASS=$(grep '^REDIS_PASSWORD=' "$PKMN_LOCAL" | cut -d= -f2-)
else
  source "$ENV_DEPLOY"
  PKMN_CID="$INFISICAL_CLIENT_ID"
  PKMN_CSEC="$INFISICAL_CLIENT_SECRET"
  DB_PASS="$DB_PASSWORD"
  REDIS_PASS="$REDIS_PASSWORD"
fi

ssh "$NETCUP" "cat > '${PKMN_PATH}/.env'" << EOF
INFISICAL_CLIENT_ID=${PKMN_CID}
INFISICAL_CLIENT_SECRET=${PKMN_CSEC}
DB_PASSWORD=${DB_PASS}
REDIS_PASSWORD=${REDIS_PASS}
EOF
ssh "$NETCUP" "chmod 600 '${PKMN_PATH}/.env'"
log ".env written"

step "4/5: Pull code and rebuild"
ssh "$NETCUP" "cd '${PKMN_PATH}' && git stash 2>/dev/null; git pull origin main"
log "Code pulled"
ssh "$NETCUP" "cd '${PKMN_PATH}' && docker compose -f docker-compose.prod.yml up -d --build"
log "Containers rebuilt"

step "5/5: Verify injection"
echo "Waiting 15s for startup..."
sleep 15
LOGS=$(ssh "$NETCUP" "docker logs pkmn-api 2>&1 | grep '\[infisical\]' | tail -3" || true)
if echo "$LOGS" | grep -q "Injected"; then
  log "Secret injection confirmed!"
  echo "$LOGS" | sed 's/^/  /'
else
  echo "Container logs (last 20 lines):"
  ssh "$NETCUP" "docker logs pkmn-api 2>&1 | tail -20" | sed 's/^/  /'
fi

echo ""
log "Done! Verify all 3 containers:"
echo "  ssh $NETCUP 'docker logs pkmn-api 2>&1 | grep infisical'"
echo "  ssh $NETCUP 'docker logs pkmn-celery-worker 2>&1 | grep infisical'"
echo "  ssh $NETCUP 'docker logs pkmn-celery-beat 2>&1 | grep infisical'"
