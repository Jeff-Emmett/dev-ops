#!/usr/bin/env bash
# Rotate the FalkorDB (Redis-protocol) password used by KOI store, the
# falkormem MCP, and falkor-cypher MCP.
#
# Sequence:
#   1. Generate a new 32-char hex password.
#   2. Atomically swap FALKORDB_PASSWORD in /opt/apps/falkordb/.env (timestamped
#      backup beside the file).
#   3. Apply the new password live via Redis `CONFIG SET requirepass` over
#      a connection authenticated with the OLD password — this works because
#      Redis lets you change requirepass on an authenticated connection.
#   4. `docker compose up -d` falkordb so the new password is also baked in
#      via the REDIS_ARGS env var (defends against container restart).
#   5. Smoke-test: open a fresh connection with the NEW password, run PING.
#   6. inventory_mark_rotated.
#
# Failure modes:
#   - If step 3 fails (auth error, network blip), the .env still has the new
#     value but the running server is unchanged. Recover by reverting the
#     .env from .bak and re-running, or by restarting falkordb (it picks up
#     the new value from .env on cold start).
#   - Downstream clients (rspace-online KOI store, MCPs on local WSL2) still
#     hold the OLD password — this script does NOT update them. Per the
#     inventory `notes` block, the user needs to update each client
#     connection string in lockstep. Script logs a reminder.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

parse_common_args "$@"

NAME="falkordb-password"
SSH_TARGET="${SSH_TARGET:-netcup-full}"
NETCUP_ENV="${NETCUP_ENV:-/opt/apps/falkordb/.env}"
CONTAINER="${CONTAINER:-falkordb}"

log "rotating $NAME (DRY_RUN=$DRY_RUN)"

# Step 1: new 64-char hex password (256 bits).
if (( DRY_RUN )); then
  NEW_PW="dry-run-placeholder"
  log "DRY-RUN: would generate new 64-char hex password"
else
  NEW_PW=$(openssl rand -hex 32)
  log "generated new password"
fi

# Step 2: pull old password from .env, then swap in new one.
if (( DRY_RUN )); then
  log "DRY-RUN: would read OLD password + scp-edit-scp $NETCUP_ENV"
  OLD_PW="dry-run-old"
else
  OLD_PW=$(ssh "$SSH_TARGET" "grep -E '^FALKORDB_PASSWORD=' $NETCUP_ENV | sed 's/^FALKORDB_PASSWORD=//; s/^\"//; s/\"$//'")
  [[ -n "$OLD_PW" ]] || die "could not read OLD FALKORDB_PASSWORD from $NETCUP_ENV"

  TS=$(date -u +%Y%m%d-%H%M%S)
  TMP_IN=$(mktemp); TMP_OUT=$(mktemp)
  trap "rm -f $TMP_IN $TMP_OUT" EXIT
  scp -q "$SSH_TARGET:$NETCUP_ENV" "$TMP_IN"
  ssh "$SSH_TARGET" "cp $NETCUP_ENV ${NETCUP_ENV}.bak-pre-rotate-${TS}"

  NEW_PW_ENV="$NEW_PW" python3 <<PY
import os, pathlib, re
src, dst = "$TMP_IN", "$TMP_OUT"
new = os.environ["NEW_PW_ENV"]
t = pathlib.Path(src).read_text()
t, n = re.subn(r'(?m)^FALKORDB_PASSWORD=.*$', f'FALKORDB_PASSWORD={new}', t)
assert n == 1, f"expected exactly 1 FALKORDB_PASSWORD line, got {n}"
pathlib.Path(dst).write_text(t)
PY

  scp -q "$TMP_OUT" "$SSH_TARGET:$NETCUP_ENV"
  ssh "$SSH_TARGET" "chmod 600 $NETCUP_ENV"
  log "Netcup .env updated"
fi

# Step 3: apply via CONFIG SET while the server is still running with old PW.
if (( DRY_RUN )); then
  log "DRY-RUN: would CONFIG SET requirepass <new> via OLD-PW authenticated client"
else
  ssh "$SSH_TARGET" "docker exec $CONTAINER redis-cli -a '$OLD_PW' --no-auth-warning CONFIG SET requirepass '$NEW_PW'" >/dev/null \
    || die "CONFIG SET failed — .env shows new value but server is unchanged; restart $CONTAINER to converge"
  log "live CONFIG SET requirepass applied"
fi

# Step 4: recreate so REDIS_ARGS env reload also reflects (defensive).
if (( DRY_RUN )); then
  log "DRY-RUN: would docker compose up -d $CONTAINER"
else
  ssh "$SSH_TARGET" "cd /opt/apps/falkordb && docker compose up -d $CONTAINER" >/dev/null
  sleep 3
fi

# Step 5: smoke-test PING with new password.
if (( DRY_RUN )); then
  log "DRY-RUN: would PING with new password"
else
  PING=$(ssh "$SSH_TARGET" "docker exec $CONTAINER redis-cli -a '$NEW_PW' --no-auth-warning ping" 2>&1 | tr -d '\r\n')
  if [[ "$PING" != "PONG" ]]; then
    die "post-rotation PING failed: '$PING' — recover from backup ${NETCUP_ENV}.bak-pre-rotate-${TS}"
  fi
  log "post-rotation PING ok"
fi

# Step 6: bump last_rotated.
if (( DRY_RUN )); then
  log "DRY-RUN: would inventory_mark_rotated $NAME"
else
  TODAY=$(inventory_mark_rotated "$NAME")
  log "inventory_mark_rotated → $TODAY"
fi

cat >&2 <<EOF

[$(date -u +%H:%M:%SZ)] ⚠ Downstream client clients still hold the OLD password:
    - rspace-online KOI store (if KOI_STORE=falkordb): /opt/rspace-online/.env on Netcup
    - falkormem MCP (local WSL2): ~/.claude/mcp-servers/ or wherever you configured it
    - falkor-cypher MCP (local WSL2): same

Update each client's connection string (grep for FALKORDB_PASSWORD in
~/Github and on Netcup), then test. Until you do, those clients will
fail to connect.
EOF

log "rotation complete"
