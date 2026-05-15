#!/usr/bin/env bash
# Generic Postgres password rotation for Dockerized services on Netcup.
#
# Usage: rotate-postgres-password.sh [--dry-run] <service-profile>
#
# A "service profile" is a small bash file in ./postgres-profiles/<name>.sh
# that exports the per-service knobs (container names, env-var name, .env
# path, restart command). See ./postgres-profiles/n8n.sh for the canonical
# template.
#
# Sequence:
#   1. Generate a new 32-char hex password.
#   2. Read old password from <service>.env so we have a working ALTER USER
#      connection.
#   3. `ALTER USER <user> WITH PASSWORD '<new>'` on the Postgres container.
#   4. Atomically swap the password in <service>.env (timestamped backup).
#   5. Restart the consumer container(s) so they pick up the new env.
#   6. Smoke-test: open a fresh connection with the new password (psql -c '\q').
#   7. inventory_mark_rotated (uses the profile's INVENTORY_NAME).
#
# Failure modes:
#   - ALTER USER fails → no .env change yet; profile's `OLD_PW_ENV_VAR` was
#     wrong, container down, or pg auth not via password.
#   - .env edit fails → server has new PW, .env has old. Recover by manually
#     setting the .env value to the new one (also saved to a recovery file
#     printed by this script on failure).
#   - Smoke test fails → check container is up + restarted; consumer's new
#     env wasn't picked up.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--dry-run] <service-profile>

Available profiles:
$(ls "${SCRIPT_DIR}/postgres-profiles/"*.sh 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.sh$//; s/^/  - /' || echo '  (none yet — create one in postgres-profiles/)')

A profile is a bash file that exports:
  INVENTORY_NAME, PG_CONTAINER, PG_DB, PG_USER, ENV_PATH,
  ENV_VAR (the var name to swap), SSH_TARGET,
  RESTART_CMD (shell command to run after .env update)
USAGE
}

# Parse profile name + flags.
PROFILE_NAME=""
while (( $# > 0 )); do
  case "$1" in
    --dry-run|-n) DRY_RUN=1; shift ;;
    --help|-h)    usage; exit 0 ;;
    --*)          die "unknown flag: $1" ;;
    *)            PROFILE_NAME="$1"; shift ;;
  esac
done
[[ -z "$PROFILE_NAME" ]] && { usage; exit 1; }

PROFILE_PATH="${SCRIPT_DIR}/postgres-profiles/${PROFILE_NAME}.sh"
[[ -f "$PROFILE_PATH" ]] || die "no profile at $PROFILE_PATH"
# shellcheck disable=SC1090
source "$PROFILE_PATH"

# Validate required profile vars.
for v in INVENTORY_NAME PG_CONTAINER PG_DB PG_USER ENV_PATH ENV_VAR SSH_TARGET RESTART_CMD; do
  [[ -n "${!v:-}" ]] || die "profile $PROFILE_NAME missing required var: $v"
done

log "rotating $INVENTORY_NAME via profile $PROFILE_NAME (DRY_RUN=$DRY_RUN)"

# Step 1: new password.
if (( DRY_RUN )); then
  NEW_PW="dry-run-placeholder"
else
  NEW_PW=$(openssl rand -hex 32)
fi
log "generated new 64-char hex password"

# Step 2: read old password from .env.
if (( DRY_RUN )); then
  OLD_PW="dry-run-old"
  log "DRY-RUN: would read OLD $ENV_VAR from $ENV_PATH"
else
  OLD_PW=$(ssh "$SSH_TARGET" "grep -E '^${ENV_VAR}=' '$ENV_PATH' | sed 's/^${ENV_VAR}=//; s/^\"//; s/\"$//'")
  [[ -n "$OLD_PW" ]] || die "could not read OLD $ENV_VAR from $ENV_PATH"
fi

# Step 3: ALTER USER on the Postgres container.
if (( DRY_RUN )); then
  log "DRY-RUN: would ALTER USER $PG_USER WITH PASSWORD <new> on container $PG_CONTAINER"
else
  ssh "$SSH_TARGET" "docker exec -e PGPASSWORD='$OLD_PW' '$PG_CONTAINER' psql -U '$PG_USER' -d '$PG_DB' -c \"ALTER USER \\\"$PG_USER\\\" WITH PASSWORD '$NEW_PW';\"" >/dev/null \
    || die "ALTER USER failed — .env unchanged; check $PG_CONTAINER is running + $PG_USER has password auth"
  log "Postgres user $PG_USER password updated"
fi

# Step 4: swap in .env via scp-edit-scp.
if (( DRY_RUN )); then
  log "DRY-RUN: would scp-edit-scp $ENV_PATH replacing $ENV_VAR value"
else
  TS=$(date -u +%Y%m%d-%H%M%S)
  TMP_IN=$(mktemp); TMP_OUT=$(mktemp)
  trap "rm -f $TMP_IN $TMP_OUT" EXIT
  scp -q "$SSH_TARGET:$ENV_PATH" "$TMP_IN"
  ssh "$SSH_TARGET" "cp $ENV_PATH ${ENV_PATH}.bak-pre-rotate-${TS}"

  ENV_VAR="$ENV_VAR" NEW_PW="$NEW_PW" python3 <<PY
import os, pathlib, re
src, dst = "$TMP_IN", "$TMP_OUT"
var = os.environ["ENV_VAR"]
new = os.environ["NEW_PW"]
t = pathlib.Path(src).read_text()
t, n = re.subn(rf'(?m)^{re.escape(var)}=.*$', f'{var}={new}', t)
if n != 1:
    print(f'ERROR: expected exactly 1 {var} line, got {n}', file=__import__("sys").stderr)
    import sys; sys.exit(2)
pathlib.Path(dst).write_text(t)
PY

  if ! scp -q "$TMP_OUT" "$SSH_TARGET:$ENV_PATH"; then
    cat >&2 <<EOF
[$(date -u +%H:%M:%SZ)] FATAL: scp failed AFTER Postgres password was changed.
The DB has the new password but $ENV_PATH still has the old one.
Manual recovery:
  ssh $SSH_TARGET
  edit $ENV_PATH and set ${ENV_VAR}=$NEW_PW
  $RESTART_CMD
EOF
    exit 1
  fi
  ssh "$SSH_TARGET" "chmod 600 $ENV_PATH"
  log ".env updated at $ENV_PATH"
fi

# Step 5: restart consumer(s).
if (( DRY_RUN )); then
  log "DRY-RUN: would run \`$RESTART_CMD\` on $SSH_TARGET"
else
  ssh "$SSH_TARGET" "$RESTART_CMD" >/dev/null
  sleep 4
  log "consumer restart: $RESTART_CMD"
fi

# Step 6: smoke-test with the new password.
if (( DRY_RUN )); then
  log "DRY-RUN: would psql -U $PG_USER with new password"
else
  CHECK=$(ssh "$SSH_TARGET" "docker exec -e PGPASSWORD='$NEW_PW' '$PG_CONTAINER' psql -U '$PG_USER' -d '$PG_DB' -tAc 'SELECT 1;'" 2>&1 | tr -d '\r\n')
  if [[ "$CHECK" != "1" ]]; then
    die "post-rotation psql smoke test failed: '$CHECK' — backups exist at ${ENV_PATH}.bak-pre-rotate-${TS}"
  fi
  log "smoke test: psql SELECT 1 returned $CHECK ✓"
fi

# Step 7: bump inventory.
if (( DRY_RUN )); then
  log "DRY-RUN: would inventory_mark_rotated $INVENTORY_NAME"
else
  TODAY=$(inventory_mark_rotated "$INVENTORY_NAME")
  log "inventory_mark_rotated → $TODAY"
fi

log "rotation complete for $INVENTORY_NAME"
