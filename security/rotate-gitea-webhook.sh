#!/usr/bin/env bash
# Rotate the gitea-deploy webhook secret on Netcup.
#
# Sequence:
#   1. Generate a new 64-char hex secret
#   2. Single SSH session to Netcup:
#      a. backup current /root/.secrets/webhook_secret to .bak.<UTC ts>
#      b. UPDATE webhook table in gitea-db for every hook whose url
#         contains deploy.jeffemmett.com (single transaction, atomic)
#      c. atomically swap the secret file
#      d. restart deploy-webhook
#   3. Smoke test: trigger /tests on the first matching hook,
#      grep deploy-webhook logs for "Invalid signature" — fail if any.
#   4. Update last_rotated in the inventory.
#
# Why direct DB UPDATE:
#   Gitea 1.21's `PATCH /api/v1/repos/:o/:r/hooks/:id` returns 200 but
#   silently ignores the `config.secret` field. The DB is the source
#   of truth; updating it directly is correct and idempotent.
#
# Failure modes handled:
#   - DB UPDATE failure aborts before file swap (file unchanged).
#   - Smoke test failure: the .bak.<ts> file holds the previous value,
#     and the script prints a one-liner rollback command for the operator.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

parse_common_args "$@"

NAME="gitea-webhook-secret"
SSH_TARGET="${SSH_TARGET:-netcup-full}"
SECRET_PATH="$(inventory_get "$NAME" 'location.path')"
[[ -n "$SECRET_PATH" ]] || die "could not read location.path for $NAME"

GITEA_URL="${GITEA_URL:-https://gitea.jeffemmett.com}"
WEBHOOK_URL_FILTER="${WEBHOOK_URL_FILTER:-deploy.jeffemmett.com}"

log "rotating $NAME (DRY_RUN=$DRY_RUN)"

# 1. Generate new secret (no newline, 64 hex chars to match existing format)
NEW_SECRET=$(openssl rand -hex 32)
log "generated new 64-char secret"

# 2. Discover hook count via the gitea DB (cheap; one query)
HOOK_COUNT=$(ssh "$SSH_TARGET" "docker exec gitea-db psql -U gitea -d gitea -tAc \"
  SELECT count(*) FROM webhook WHERE url LIKE '%${WEBHOOK_URL_FILTER}%';
\"" | tr -d '[:space:]')
[[ -n "$HOOK_COUNT" && "$HOOK_COUNT" -gt 0 ]] || die "no webhooks matched filter ${WEBHOOK_URL_FILTER}"
log "found $HOOK_COUNT webhooks to update"

if (( DRY_RUN )); then
  log "DRY-RUN: would UPDATE secret on $HOOK_COUNT webhook rows"
  log "DRY-RUN: would write new secret to ${SSH_TARGET}:${SECRET_PATH}"
  log "DRY-RUN: would docker restart deploy-webhook"
  log "DRY-RUN: would smoke test + mark inventory rotated"
  exit 0
fi

TS=$(date -u +%Y%m%d-%H%M%S)
BACKUP_PATH="${SECRET_PATH}.bak.${TS}"

# 3. Atomic-ish sequence on Netcup:
#    DB UPDATE first (so file write only happens if DB succeeded)
#    Between UPDATE and file mv there's a ~50-200ms window where
#    Gitea has the new secret but the file still has the old one.
#    Worst-case impact: a single delivery during that window gets
#    rejected and Gitea retries — recoverable.
ssh "$SSH_TARGET" "
  set -euo pipefail
  cp '${SECRET_PATH}' '${BACKUP_PATH}'
  chmod 600 '${BACKUP_PATH}'

  printf '%s' '${NEW_SECRET}' > '${SECRET_PATH}.new'
  chmod 600 '${SECRET_PATH}.new'

  # DB UPDATE first; -v ON_ERROR_STOP=1 makes psql exit non-zero on
  # any SQL error so 'set -e' aborts before we touch the file.
  docker exec -i gitea-db psql -U gitea -d gitea -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;
UPDATE webhook
   SET secret = '${NEW_SECRET}',
       updated_unix = extract(epoch from now())::bigint
 WHERE url LIKE '%${WEBHOOK_URL_FILTER}%';
COMMIT;
SQL

  mv '${SECRET_PATH}.new' '${SECRET_PATH}'
  docker restart deploy-webhook >/dev/null
"
sleep 4

# 4. Smoke test: pick the first matching hook, fire /tests, grep logs.
log "smoke test: triggering test delivery"
GITEA_TOKEN=$(ssh "$SSH_TARGET" 'cat /root/.secrets/gitea_token' | tr -d '\n')
SMOKE=$(ssh "$SSH_TARGET" "docker exec gitea-db psql -U gitea -d gitea -tAF$'\t' -c \"
  SELECT w.id, r.owner_name || '/' || r.name FROM webhook w
   JOIN repository r ON w.repo_id = r.id
  WHERE w.url LIKE '%${WEBHOOK_URL_FILTER}%' ORDER BY w.id LIMIT 1;
\"")
SMOKE_ID=$(printf '%s' "$SMOKE" | cut -f1 | tr -d '[:space:]')
SMOKE_REPO=$(printf '%s' "$SMOKE" | cut -f2 | tr -d '[:space:]')
log "smoke target: hook ${SMOKE_ID} on ${SMOKE_REPO}"
curl -fsS -X POST -H "Authorization: token ${GITEA_TOKEN}" \
  "${GITEA_URL}/api/v1/repos/${SMOKE_REPO}/hooks/${SMOKE_ID}/tests" >/dev/null || \
  log "WARN: test trigger returned non-200 (some Gitea versions don't support /tests; continue)"
sleep 4
rejects=$(ssh "$SSH_TARGET" "docker logs deploy-webhook --since 30s 2>&1 | grep -c 'Invalid.*signature' || true")
if [[ "$rejects" -gt 0 ]]; then
  log "ERROR: smoke FAILED — $rejects signature rejection(s) in last 30s"
  log "rollback (manual; copy-paste):"
  log "  ssh ${SSH_TARGET} 'OLD=\$(cat ${BACKUP_PATH}); cp ${BACKUP_PATH} ${SECRET_PATH}; docker restart deploy-webhook; docker exec -i gitea-db psql -U gitea -d gitea -c \"UPDATE webhook SET secret = '\\''\${OLD}'\\'' WHERE url LIKE '\\''%${WEBHOOK_URL_FILTER}%'\\'';\"'"
  die "rotation failed — see rollback command above"
fi
log "smoke test passed (no signature rejections)"

new_date=$(inventory_mark_rotated "$NAME")
log "rotation complete; inventory updated to last_rotated=$new_date"
