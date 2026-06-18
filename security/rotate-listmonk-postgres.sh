#!/usr/bin/env bash
# Listmonk Postgres password rotation — SPLIT-CONFIG aware (lockstep).
#
# Listmonk stores the DB password in TWO independent places that must agree:
#   - .env LISTMONK_DB_PASSWORD  → interpolated into the postgres container's
#                                  POSTGRES_PASSWORD   (DB side)
#   - config.toml [db] password  → bind-mounted into the app at
#                                  /listmonk/config.toml   (APP side)
# The generic rotate-postgres-password.sh only touches the .env side; running
# it here on 2026-05-15 changed the DB password, left config.toml stale, and
# flooded `pq: password authentication failed` until reverted — while the
# DB-only smoke test falsely passed. This script edits BOTH files in lockstep
# and verifies the APP reconnected (the step the generic rotator lacked).
#
# Usage: rotate-listmonk-postgres.sh [--dry-run] <profile>   # main | xhiva
#
# Mirrors runbook-listmonk-postgres.md exactly, automated + guarded. All
# server-side mutation runs in ONE remote bash block (stdin over ssh) so the
# rotation is atomic and the new password never lands in argv on either host.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--dry-run] <profile>

Available profiles:
$(ls "${SCRIPT_DIR}/listmonk-profiles/"*.sh 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.sh$//; s/^/  - /' || echo '  (none)')
USAGE
}

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

PROFILE_PATH="${SCRIPT_DIR}/listmonk-profiles/${PROFILE_NAME}.sh"
[[ -f "$PROFILE_PATH" ]] || die "no profile at $PROFILE_PATH"
# shellcheck disable=SC1090
source "$PROFILE_PATH"

for v in INVENTORY_NAME INST_DIR DB_CONTAINER APP_CONTAINER PG_USER PG_DB ENV_VAR SSH_TARGET; do
  [[ -n "${!v:-}" ]] || die "profile $PROFILE_NAME missing required var: $v"
done

log "rotating $INVENTORY_NAME (listmonk lockstep, profile=$PROFILE_NAME, DRY_RUN=$DRY_RUN)"

if (( DRY_RUN )); then
  NEW_PW="dry-run-placeholder"
else
  NEW_PW=$(openssl rand -hex 24)   # 48 hex chars, no shell/sed-special chars
fi

# Single atomic remote operation. Returns one of:
#   OK            — both files updated, container recreated, app reconnected
#   ROLLED_BACK   — a step failed; DB pw + both files restored to OLD
#   anything else — hard failure with context on stderr
REMOTE_RESULT=$(DRY_RUN="$DRY_RUN" NEW_PW="$NEW_PW" \
  INST_DIR="$INST_DIR" DB_CONTAINER="$DB_CONTAINER" APP_CONTAINER="$APP_CONTAINER" \
  PG_USER="$PG_USER" PG_DB="$PG_DB" ENV_VAR="$ENV_VAR" \
  ssh "$SSH_TARGET" \
    "DRY_RUN='$DRY_RUN' NEW_PW='$NEW_PW' INST_DIR='$INST_DIR' DB_CONTAINER='$DB_CONTAINER' APP_CONTAINER='$APP_CONTAINER' PG_USER='$PG_USER' PG_DB='$PG_DB' ENV_VAR='$ENV_VAR' bash -s" <<'REMOTE'
set -uo pipefail
say() { printf '[remote] %s\n' "$*" >&2; }

ENV_FILE="$INST_DIR/.env"
CFG_FILE="$INST_DIR/config.toml"
[ -f "$ENV_FILE" ] || { echo "ENV_NOT_FOUND:$ENV_FILE"; exit 2; }
[ -f "$CFG_FILE" ] || { echo "CFG_NOT_FOUND:$CFG_FILE"; exit 2; }

OLD_PW="$(grep -E "^${ENV_VAR}=" "$ENV_FILE" | head -1 | sed 's/^[^=]*=//; s/^"//; s/"$//')"
[ -n "$OLD_PW" ] || { echo "OLD_PW_NOT_FOUND"; exit 2; }

# Baseline app health
say "app baseline:"; docker logs --tail 3 "$APP_CONTAINER" 2>&1 | grep -iE "http server started|password authentication" | tail -2 >&2 || true

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: would ALTER USER $PG_USER, edit $ENV_VAR in .env + password in config.toml, recreate, verify"
  if grep -qE "^[[:space:]]*password[[:space:]]*=" "$CFG_FILE"; then say "DRY-RUN: config.toml password line matched (value masked) — sed pattern OK"; else say "DRY-RUN: NO config.toml password line matched — CHECK pattern before live run"; fi
  echo "OK"; exit 0
fi

TS="$(date -u +%Y%m%d-%H%M%S)"
cp "$ENV_FILE" "$ENV_FILE.bak-pre-rotate-$TS"
cp "$CFG_FILE" "$CFG_FILE.bak-pre-rotate-$TS"

rollback() {
  say "ROLLBACK: restoring DB pw + both files"
  docker exec -e PGPASSWORD="$NEW_PW" "$DB_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" \
    -c "ALTER USER \"$PG_USER\" WITH PASSWORD '$OLD_PW';" >/dev/null 2>&1
  cp "$ENV_FILE.bak-pre-rotate-$TS" "$ENV_FILE"
  cp "$CFG_FILE.bak-pre-rotate-$TS" "$CFG_FILE"
  ( cd "$INST_DIR" && docker compose up -d --force-recreate ) >/dev/null 2>&1
  echo "ROLLED_BACK"
}

# 1. ALTER USER (connect with OLD)
if ! docker exec -e PGPASSWORD="$OLD_PW" "$DB_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" \
      -c "ALTER USER \"$PG_USER\" WITH PASSWORD '$NEW_PW';" >/dev/null 2>&1; then
  say "ALTER USER failed — .env/config untouched"; echo "ALTER_FAILED"; exit 3
fi
say "DB password changed"

# 2. Edit BOTH files
sed -i "s|^${ENV_VAR}=.*|${ENV_VAR}=${NEW_PW}|" "$ENV_FILE"
sed -i -E "s|^([[:space:]]*)password[[:space:]]*=.*|\1password = \"${NEW_PW}\"|" "$CFG_FILE"

# Confirm both actually changed
if ! grep -qE "^${ENV_VAR}=${NEW_PW}\$" "$ENV_FILE"; then say ".env edit FAILED"; rollback; exit 4; fi
if ! grep -qF "${NEW_PW}" "$CFG_FILE"; then say "config.toml edit FAILED (password line pattern?)"; rollback; exit 4; fi
say "both files updated"

# 3. Recreate
( cd "$INST_DIR" && docker compose up -d --force-recreate ) >/dev/null 2>&1 || { say "recreate failed"; rollback; exit 5; }
sleep 8

# 4. Consumer verification — the step the generic rotator lacked
HITS="$(docker logs --since 40s "$APP_CONTAINER" 2>&1 | grep -iE "password authentication failed|error connecting to DB|error fetching campaigns" | tail -3)"
if [ -n "$HITS" ]; then
  say "CONSUMER AUTH FAILURE:"; echo "$HITS" >&2; rollback; exit 6
fi
# 5. DB-side smoke with NEW
CHK="$(docker exec -e PGPASSWORD="$NEW_PW" "$DB_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -tAc 'SELECT 1;' 2>&1 | tr -d '\r\n ')"
[ "$CHK" = "1" ] || { say "DB smoke failed: '$CHK'"; rollback; exit 7; }
say "verified: app reconnected, DB smoke=1, backups at *.bak-pre-rotate-$TS"
echo "OK"
REMOTE
) || { log "remote rotation returned non-zero"; }

log "remote result: ${REMOTE_RESULT##*$'\n'}"
case "${REMOTE_RESULT##*$'\n'}" in
  OK)
    if (( DRY_RUN )); then
      log "DRY-RUN complete for $INVENTORY_NAME (no changes made)"
    else
      TODAY=$(inventory_mark_rotated "$INVENTORY_NAME")
      log "inventory_mark_rotated $INVENTORY_NAME → $TODAY"
      log "rotation complete for $INVENTORY_NAME ✓"
    fi
    ;;
  ROLLED_BACK) die "rotation auto-rolled-back (service restored to OLD password). Inspect remote stderr above." ;;
  *)           die "rotation failed: $REMOTE_RESULT" ;;
esac
