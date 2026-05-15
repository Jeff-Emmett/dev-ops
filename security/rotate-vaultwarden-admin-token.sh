#!/usr/bin/env bash
# Rotate the Vaultwarden admin token (admin-panel passphrase).
#
# Sequence:
#   1. Generate a new passphrase (32-char URL-safe random).
#   2. Compute its argon2id PHC hash via the vaultwarden container's built-in
#      `vaultwarden hash` subcommand (handles params + salt correctly).
#   3. Write plaintext to ~/.secrets/private/vaultwarden_admin_passphrase_jeff.txt
#      (mode 600). Keep a timestamped backup of the old value.
#   4. Update VW_ADMIN_TOKEN in /opt/apps/vaultwarden/.env on Netcup. The
#      hash contains $ chars that compose interpolates — double them to $$
#      per docker_compose_dollar_escaping memory.
#   5. Recreate the vaultwarden container so it loads the new env.
#   6. Login-test the admin panel via the same loopback flow used in TASK-86
#      verification — POST /admin with the new plaintext, confirm HTTP 303
#      and the VW_ADMIN cookie.
#   7. Call inventory_mark_rotated.
#
# Failure modes:
#   - Login test fails → backups are timestamped; revert manually.
#   - argon2 hash command fails → no .env change made yet (early-fail).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

parse_common_args "$@"

NAME="vaultwarden-admin-token"
SSH_TARGET="${SSH_TARGET:-netcup-full}"
LOCAL_PLAINTEXT="${LOCAL_PLAINTEXT:-${HOME}/.secrets/private/vaultwarden_admin_passphrase_jeff.txt}"
NETCUP_ENV="${NETCUP_ENV:-/opt/apps/vaultwarden/.env}"
VW_HOST="${VW_HOST:-passwords.jeffemmett.com}"

log "rotating $NAME (DRY_RUN=$DRY_RUN)"

# Step 1: new passphrase. 32 chars base64url ≈ 192 bits entropy.
if (( DRY_RUN )); then
  log "DRY-RUN: would generate new 32-char passphrase"
  NEW_PLAINTEXT="dry-run-placeholder-do-not-use"
else
  NEW_PLAINTEXT=$(openssl rand -base64 24 | tr -d '\n=' | tr '+/' '-_')
  log "generated new passphrase (length=${#NEW_PLAINTEXT})"
fi

# Step 2: argon2id hash via vaultwarden binary inside the running container.
# `vaultwarden hash <password>` returns the PHC string ready for ADMIN_TOKEN.
if (( DRY_RUN )); then
  log "DRY-RUN: would docker exec vaultwarden /vaultwarden hash <new>"
  NEW_HASH='$argon2id$v=19$m=65540,t=3,p=4$dryrun$dryrun'
else
  NEW_HASH=$(ssh "$SSH_TARGET" "echo '$NEW_PLAINTEXT' | docker exec -i vaultwarden /vaultwarden hash --preset bitwarden 2>&1 | grep -E '^\\\$argon2'" || true)
  [[ -n "$NEW_HASH" ]] || die "vaultwarden hash returned empty"
  log "computed argon2id hash (${#NEW_HASH} chars)"
fi

# Step 3: write plaintext locally (mode 600), backup old.
if (( DRY_RUN )); then
  log "DRY-RUN: would write $LOCAL_PLAINTEXT (mode 600, backup .bak-pre-rotate-TS)"
else
  TS=$(date -u +%Y%m%d-%H%M%S)
  [[ -f "$LOCAL_PLAINTEXT" ]] && cp -p "$LOCAL_PLAINTEXT" "${LOCAL_PLAINTEXT}.bak-pre-rotate-${TS}"
  install -m 0600 /dev/stdin "$LOCAL_PLAINTEXT" <<<"$NEW_PLAINTEXT"
  log "wrote plaintext to $LOCAL_PLAINTEXT"
fi

# Step 4: update VW_ADMIN_TOKEN in Netcup .env. Double $ → $$ for compose.
if (( DRY_RUN )); then
  log "DRY-RUN: would scp-edit-scp $NETCUP_ENV with new VW_ADMIN_TOKEN"
else
  TMP_IN=$(mktemp); TMP_OUT=$(mktemp)
  trap "rm -f $TMP_IN $TMP_OUT" EXIT
  scp -q "$SSH_TARGET:$NETCUP_ENV" "$TMP_IN"
  ssh "$SSH_TARGET" "cp $NETCUP_ENV ${NETCUP_ENV}.bak-pre-rotate-${TS}"

  ESCAPED_HASH="${NEW_HASH//\$/\$\$}"
  NEW_HASH_ESC="$ESCAPED_HASH" python3 <<PY
import os, pathlib, re
src, dst = "$TMP_IN", "$TMP_OUT"
new = os.environ["NEW_HASH_ESC"]
t = pathlib.Path(src).read_text()
t, n = re.subn(r'(?m)^VW_ADMIN_TOKEN=.*$', lambda m: f'VW_ADMIN_TOKEN="{new}"', t)
assert n == 1, f"expected exactly 1 VW_ADMIN_TOKEN line, got {n}"
pathlib.Path(dst).write_text(t)
PY

  scp -q "$TMP_OUT" "$SSH_TARGET:$NETCUP_ENV"
  ssh "$SSH_TARGET" "chmod 600 $NETCUP_ENV"
fi
log "Netcup .env updated"

# Step 5: recreate vaultwarden container.
if (( DRY_RUN )); then
  log "DRY-RUN: would docker compose up -d vaultwarden"
else
  ssh "$SSH_TARGET" "cd /opt/apps/vaultwarden && docker compose up -d" >/dev/null
  sleep 4
fi

# Step 6: verify by logging in via loopback (same pattern as TASK-86).
if (( DRY_RUN )); then
  log "DRY-RUN: would POST /admin via loopback to confirm new passphrase works"
else
  RESULT=$(printf '%s' "$NEW_PLAINTEXT" | ssh "$SSH_TARGET" '
    read -r TOK
    COOKIES=$(mktemp)
    HTTP=$(curl -sS -c "$COOKIES" -o /dev/null -w "%{http_code}" \
      -H "Host: '"$VW_HOST"'" \
      -X POST "http://127.0.0.1/admin" \
      --data-urlencode "token=$TOK" \
      --data-urlencode "redirect=")
    COOKIE_OK=$(grep -c VW_ADMIN "$COOKIES")
    rm -f "$COOKIES"
    echo "http=$HTTP cookie=$COOKIE_OK"
  ')
  log "login probe: $RESULT"
  if [[ "$RESULT" != *"http=303"* || "$RESULT" != *"cookie=1"* ]]; then
    die "login test FAILED — backups: ${LOCAL_PLAINTEXT}.bak-pre-rotate-${TS} + ${NETCUP_ENV}.bak-pre-rotate-${TS}"
  fi
fi

# Step 7: bump last_rotated.
if (( DRY_RUN )); then
  log "DRY-RUN: would inventory_mark_rotated $NAME"
else
  TODAY=$(inventory_mark_rotated "$NAME")
  log "inventory_mark_rotated → $TODAY"
fi

log "rotation complete"
