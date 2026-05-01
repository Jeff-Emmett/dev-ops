#!/usr/bin/env bash
# Rotate the engine-pool-auth-token shared across morpheus-engine-pool +
# every forge that calls /jobs/* (clip-forge backend, image-forge).
#
# Sequence:
#   1. Generate a new 64-char hex token
#   2. Atomically swap ENGINE_POOL_AUTH_TOKEN in all three .env files on
#      Netcup, with timestamped backups
#   3. Restart engine-pool-server FIRST so the new token is accepted before
#      any client tries it (server briefly accepts both old + new mid-roll
#      because clients haven't restarted yet — but the new token is the
#      only one engine-pool-server itself knows after this step)
#   4. Restart image-forge + clip-forge backend so they pick up the new
#      token from their .env files
#   5. Smoke-test by running the integration smoke script inside
#      clip-forge-backend-1 (which has the new token, ffmpeg, python, and
#      can reach engine-pool over traefik-public)
#   6. Update last_rotated in the inventory
#
# Failure modes handled:
#   - If the smoke test fails, we surface the failure but DON'T roll back.
#     The .env backups are kept (timestamped) so an operator can manually
#     restore. Auto-rollback is dangerous when the failure mode is a
#     transient (e.g. an unrelated container being slow to restart).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

parse_common_args "$@"

NAME="engine-pool-auth-token"
SSH_TARGET="${SSH_TARGET:-netcup-full}"
SMOKE_TARGET="${SMOKE_TARGET:-clip-forge-backend-1}"
SMOKE_SCRIPT_LOCAL="${SMOKE_SCRIPT_LOCAL:-${SCRIPT_DIR}/../../morpheus-engine-pool/tests/integration-smoke.sh}"
SMOKE_SCRIPT_LOCAL_ALT="${HOME}/Github/morpheus-engine-pool/tests/integration-smoke.sh"

log "rotating $NAME (DRY_RUN=$DRY_RUN)"

NEW_TOKEN=$(openssl rand -hex 32)
log "generated new 64-char token"

# Read paths from inventory.
PATHS_RAW=$(python3 - <<'PY'
import yaml
with open("/home/jeffe/Github/dev-ops/security/secrets-inventory.yaml") as f:
    d = yaml.safe_load(f)
for s in d['secrets']:
    if s['name'] == 'engine-pool-auth-token':
        for p in s['location']['paths']:
            print(p)
        break
PY
)
mapfile -t ENV_PATHS <<< "$PATHS_RAW"
[[ "${#ENV_PATHS[@]}" -ge 1 ]] || die "could not read paths from inventory"
log "will update ${#ENV_PATHS[@]} .env files: ${ENV_PATHS[*]}"

# Resolve the smoke script — either co-located in dev-ops via worktree
# layout, or sibling Github checkout.
SMOKE_SCRIPT_LOCAL_RESOLVED=""
if [[ -f "$SMOKE_SCRIPT_LOCAL" ]]; then
  SMOKE_SCRIPT_LOCAL_RESOLVED="$SMOKE_SCRIPT_LOCAL"
elif [[ -f "$SMOKE_SCRIPT_LOCAL_ALT" ]]; then
  SMOKE_SCRIPT_LOCAL_RESOLVED="$SMOKE_SCRIPT_LOCAL_ALT"
else
  log "WARN: smoke script not found at $SMOKE_SCRIPT_LOCAL or $SMOKE_SCRIPT_LOCAL_ALT — rotation will skip smoke step"
fi

# 2. Atomic .env swap.
if (( DRY_RUN )); then
  for p in "${ENV_PATHS[@]}"; do
    log "DRY-RUN: would update ENGINE_POOL_AUTH_TOKEN in $SSH_TARGET:$p"
  done
else
  TS=$(date -u +%Y%m%d-%H%M%S)
  for p in "${ENV_PATHS[@]}"; do
    log "updating $p"
    ssh "$SSH_TARGET" "sudo bash -s" <<REMOTE
set -e
test -f '$p' || { echo 'missing $p'; exit 1; }
cp '$p' '$p.bak.$TS'
chmod 600 '$p.bak.$TS'
# Drop any existing line then append fresh value (idempotent).
sed -i '/^ENGINE_POOL_AUTH_TOKEN=/d' '$p'
printf 'ENGINE_POOL_AUTH_TOKEN=%s\n' '$NEW_TOKEN' >> '$p'
chmod 600 '$p'
REMOTE
  done
fi

# 3-4. Restart server first, then clients. Server reads its env on
#      startup; clients send the bearer per-request so they pick the new
#      value as soon as their compose env reload completes.
if (( DRY_RUN )); then
  log "DRY-RUN: would restart engine-pool-server, image-forge, clip-forge backend"
else
  log "restarting engine-pool-server"
  ssh "$SSH_TARGET" "cd /opt/services/morpheus-engine-pool && docker compose up -d --no-deps engine-pool-server >/dev/null"
  sleep 3

  log "restarting image-forge"
  ssh "$SSH_TARGET" "cd /opt/services/image-forge && docker compose up -d >/dev/null"
  sleep 2

  log "restarting clip-forge backend"
  ssh "$SSH_TARGET" "cd /opt/clip-forge && docker compose up -d --no-deps backend >/dev/null"
  sleep 5
fi

# 5. Smoke test inside clip-forge-backend-1.
if (( DRY_RUN )); then
  log "DRY-RUN: would run integration-smoke.sh inside $SMOKE_TARGET"
elif [[ -n "$SMOKE_SCRIPT_LOCAL_RESOLVED" ]]; then
  log "running smoke test inside $SMOKE_TARGET"
  scp -q "$SMOKE_SCRIPT_LOCAL_RESOLVED" "$SSH_TARGET:/tmp/smoke.sh"
  if ssh "$SSH_TARGET" "
    docker cp /tmp/smoke.sh $SMOKE_TARGET:/tmp/smoke.sh \
      && docker exec $SMOKE_TARGET bash /tmp/smoke.sh
  " 2>&1 | tail -5; then
    log "smoke test PASS"
  else
    die "smoke test FAILED — .env backups kept; investigate before next rotation"
  fi
fi

# 6. Mark rotated.
if (( DRY_RUN )); then
  log "DRY-RUN: would mark $NAME rotated in inventory"
else
  new_date=$(inventory_mark_rotated "$NAME")
  log "rotation complete; inventory updated to last_rotated=$new_date"
fi
