#!/usr/bin/env bash
# Rotate the Gitea API token used by deploy-webhook (Gitea→GitHub mirror
# sync) and the local `tea` CLI. Single logical token, two file copies:
#   - /root/.secrets/gitea_token        (Netcup; Docker secret → deploy-webhook)
#   - ~/.secrets/private/gitea_token    (local dev box; tea CLI + scripts)
#
# Gitea is self-hosted so we can mint a new token with the admin CLI —
# no browser, unlike GitHub. Old-token revocation goes through the
# gitea-db Postgres directly (established pattern in this stack — see
# memory gitea_webhook_patch_bug: token/secret ops via gitea-db, not API,
# because Gitea's token API is basic-auth-only).
#
# Sequence:
#   1. Read OLD token from the file; derive its last-8.
#   2. Look up the OLD token's NAME + SCOPE in gitea-db (by last-8) so the
#      replacement preserves least-privilege automatically.
#   3. `gitea admin user generate-access-token` with the same scope.
#   4. Write NEW to both file copies (timestamped backups).
#   5. `docker restart deploy-webhook` (re-reads the Docker secret file).
#   6. Smoke-test: GET /api/v1/user with the NEW token → expect the user.
#   7. Delete the OLD token row from gitea-db by its (unique, indexed)
#      token_last_eight — surgical, touches nothing else.
#   8. inventory_mark_rotated.
#
# Failure modes:
#   - generate-access-token fails → nothing changed yet (early-fail).
#   - smoke test fails → NEW token written + consumer restarted but the
#     token doesn't work. OLD row NOT yet deleted, so revert: restore the
#     .bak files, restart deploy-webhook.
#   - DB delete fails → NEW token is live + working; OLD token still valid
#     in Gitea (hygiene issue, not a breakage). Script prints the exact
#     SQL for a manual retry.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

parse_common_args "$@"

NAME="gitea-api-token"
SSH_TARGET="${SSH_TARGET:-netcup-full}"
GITEA_USER="${GITEA_USER:-jeffemmett}"
NETCUP_FILE="${NETCUP_FILE:-/root/.secrets/gitea_token}"
LOCAL_FILE="${LOCAL_FILE:-${HOME}/.secrets/private/gitea_token}"
GITEA_C="${GITEA_C:-gitea}"
GITEA_DB_C="${GITEA_DB_C:-gitea-db}"
GITEA_URL="${GITEA_URL:-https://gitea.jeffemmett.com}"

log "rotating $NAME (DRY_RUN=$DRY_RUN)"

# Step 1: OLD token + last-8.
[[ -f "$LOCAL_FILE" ]] || die "local token file missing: $LOCAL_FILE"
OLD_TOKEN=$(tr -d '\n' < "$LOCAL_FILE")
[[ -n "$OLD_TOKEN" ]] || die "local token file empty"
OLD_LAST8="${OLD_TOKEN: -8}"
log "old token last-8: $OLD_LAST8"

# Step 2: look up OLD name + scope in gitea-db.
# SQL is piped over stdin (NOT a shell-interpolated psql -c arg) so the
# Postgres reserved-word quoting `"user"` doesn't collide with the
# ssh/docker shell layers. See memory: nested-quote SQL through
# ssh+docker+psql breaks — pipe via stdin to `docker exec -i`.
PG_LOOKUP_SQL="SELECT t.name || '|' || t.scope FROM access_token t JOIN \"user\" u ON u.id=t.uid WHERE u.lower_name='${GITEA_USER}' AND t.token_last_eight='${OLD_LAST8}';"
if (( DRY_RUN )); then
  log "DRY-RUN: would look up old token name+scope in $GITEA_DB_C"
  OLD_NAME="deploy-full-2026"; OLD_SCOPE="write:organization,write:repository,write:user"
else
  ROW=$(printf '%s' "$PG_LOOKUP_SQL" | ssh "$SSH_TARGET" "docker exec -i $GITEA_DB_C psql -U gitea -d gitea -tA" 2>/dev/null | tr -d '\r' | head -1 || true)
  [[ -n "$ROW" ]] || die "no token row with last-8 $OLD_LAST8 for $GITEA_USER — file out of sync with Gitea?"
  OLD_NAME="${ROW%%|*}"
  OLD_SCOPE="${ROW#*|}"
fi
log "old token: name='$OLD_NAME' scope='$OLD_SCOPE'"

NEW_NAME="${OLD_NAME%%-rotate-*}-rotate-$(date -u +%Y%m%d-%H%M)"

# Step 3: mint the new token with the SAME scope.
if (( DRY_RUN )); then
  log "DRY-RUN: would generate-access-token -u $GITEA_USER -t $NEW_NAME --scopes '$OLD_SCOPE'"
  NEW_TOKEN="dryrun0000000000000000000000000000000000"
else
  # Gitea logs an actions.go [E] line to STDOUT before the token, so
  # don't collapse newlines — pull the standalone 40-hex run instead.
  # `-u git` is mandatory (Gitea refuses to run as root).
  NEW_TOKEN=$(ssh "$SSH_TARGET" "docker exec -u git $GITEA_C gitea admin user generate-access-token -u '$GITEA_USER' -t '$NEW_NAME' --scopes '$OLD_SCOPE' --raw" 2>/dev/null | grep -oE '[0-9a-f]{40}' | tail -1 || true)
  if [[ -z "$NEW_TOKEN" ]]; then
    # generate-access-token may have created the row server-side even
    # though we failed to parse the value. Don't leave a dangling valid
    # credential — delete it by the (known, unique) name before dying.
    log "parse failed; cleaning up possible orphan token '$NEW_NAME'"
    printf '%s' "DELETE FROM access_token WHERE name='${NEW_NAME}';" \
      | ssh "$SSH_TARGET" "docker exec -i $GITEA_DB_C psql -U gitea -d gitea" 2>/dev/null \
      | tr -d '\r' | grep -q "DELETE 1" \
      && log "orphan '$NEW_NAME' deleted" \
      || log "no orphan row for '$NEW_NAME' (or delete failed — check manually)"
    die "generate-access-token returned no 40-hex token"
  fi
  log "minted new token '$NEW_NAME' (last-8 ${NEW_TOKEN: -8})"
fi

# Step 4: write to both copies with backups.
if (( DRY_RUN )); then
  log "DRY-RUN: would write NEW to $LOCAL_FILE + $NETCUP_FILE (timestamped .bak)"
else
  TS=$(date -u +%Y%m%d-%H%M%S)
  cp -p "$LOCAL_FILE" "${LOCAL_FILE}.bak-pre-rotate-${TS}"
  printf '%s' "$NEW_TOKEN" > "$LOCAL_FILE"
  chmod 600 "$LOCAL_FILE"
  ssh "$SSH_TARGET" "cp -p $NETCUP_FILE ${NETCUP_FILE}.bak-pre-rotate-${TS} && printf '%s' '$NEW_TOKEN' > $NETCUP_FILE && chmod 600 $NETCUP_FILE"
  log "both token files updated (backups .bak-pre-rotate-${TS})"
fi

# Step 5: restart deploy-webhook (Docker secret re-read on container start).
if (( DRY_RUN )); then
  log "DRY-RUN: would docker restart deploy-webhook"
else
  ssh "$SSH_TARGET" "docker restart deploy-webhook" >/dev/null
  sleep 3
fi

# Step 6: smoke-test the new token.
if (( DRY_RUN )); then
  log "DRY-RUN: would GET $GITEA_URL/api/v1/user with new token"
else
  WHO=$(curl -s -H "Authorization: token $NEW_TOKEN" "$GITEA_URL/api/v1/user" | python3 -c "import sys,json; print(json.load(sys.stdin).get('login',''))" 2>/dev/null || true)
  if [[ "$WHO" != "$GITEA_USER" ]]; then
    die "smoke test failed: /api/v1/user returned '$WHO' (expected $GITEA_USER). Revert: restore ${LOCAL_FILE}.bak-pre-rotate-${TS} + ${NETCUP_FILE}.bak-pre-rotate-${TS}, docker restart deploy-webhook"
  fi
  log "smoke test: /api/v1/user → $WHO ✓"
fi

# Step 7: revoke OLD token via gitea-db (surgical, by last-8).
# stdin-piped SQL (same reason as step 2).
DEL_SQL="DELETE FROM access_token WHERE token_last_eight='${OLD_LAST8}' AND uid=(SELECT id FROM \"user\" WHERE lower_name='${GITEA_USER}');"
if (( DRY_RUN )); then
  log "DRY-RUN: would DELETE old token row WHERE token_last_eight='$OLD_LAST8'"
else
  DEL_OUT=$(printf '%s' "$DEL_SQL" | ssh "$SSH_TARGET" "docker exec -i $GITEA_DB_C psql -U gitea -d gitea" 2>/dev/null | tr -d '\r' || true)
  if echo "$DEL_OUT" | grep -q "DELETE 1"; then
    log "old token row deleted (last-8 $OLD_LAST8)"
  else
    log "WARNING: old-token DB delete did not report DELETE 1 (got: ${DEL_OUT:-<empty>}). New token is live + working; old token still valid in Gitea."
    log "Manual cleanup: pipe this SQL to gitea-db —"
    echo "  printf '%s' \"$DEL_SQL\" | ssh $SSH_TARGET \"docker exec -i $GITEA_DB_C psql -U gitea -d gitea\"" >&2
  fi
fi

# Step 8: bump inventory.
if (( DRY_RUN )); then
  log "DRY-RUN: would inventory_mark_rotated $NAME"
else
  TODAY=$(inventory_mark_rotated "$NAME")
  log "inventory_mark_rotated → $TODAY"
fi

log "rotation complete for $NAME"
