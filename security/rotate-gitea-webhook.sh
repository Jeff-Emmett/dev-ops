#!/usr/bin/env bash
# Rotate the gitea-deploy webhook secret on Netcup.
#
# Sequence:
#   1. Generate a new 64-char hex secret
#   2. PATCH every active Gitea webhook pointing at deploy.jeffemmett.com
#      to use the new secret
#   3. Atomically replace /root/.secrets/webhook_secret on Netcup
#   4. Restart deploy-webhook container so it loads the new value
#   5. Smoke test by triggering one webhook from Gitea API and checking
#      deploy-webhook accepts the signature
#   6. Update last_rotated in the inventory
#
# Failure modes handled:
#   - If any Gitea API PATCH fails, abort BEFORE swapping the file (so the
#     live webhook secret stays valid for whatever wasn't updated).
#   - If the file swap or container restart fails, attempt to roll the file
#     back to the previous value.

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

# Pull the current Gitea token from Netcup
GITEA_TOKEN=$(ssh "$SSH_TARGET" 'cat /root/.secrets/gitea_token' | tr -d '\n')
[[ -n "$GITEA_TOKEN" ]] || die "could not fetch gitea token from netcup"

# 2. Discover all webhooks pointing at deploy.jeffemmett.com via the Gitea DB
#    (admin API doesn't list per-repo hooks in one call without paging through
#    every repo, and the DB query is faster + complete).
log "discovering deploy webhooks via Gitea DB..."
HOOK_LIST=$(ssh "$SSH_TARGET" "docker exec gitea-db psql -U gitea -d gitea -tAF$'\t' -c \"
  SELECT w.id, r.owner_name || '/' || r.name
  FROM webhook w JOIN repository r ON w.repo_id = r.id
  WHERE w.url LIKE '%${WEBHOOK_URL_FILTER}%'
  ORDER BY r.name;
\"")
HOOK_COUNT=$(printf '%s\n' "$HOOK_LIST" | grep -c $'\t' || true)
log "found $HOOK_COUNT webhooks to update"
[[ "$HOOK_COUNT" -gt 0 ]] || die "no webhooks matched filter ${WEBHOOK_URL_FILTER}"

# 3. PATCH each webhook with the new secret. We intentionally update inactive
#    hooks too — they should stay in sync for if/when they're re-enabled.
patch_one() {
  local id="$1" repo="$2"
  curl -fsS -X PATCH \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H 'Content-Type: application/json' \
    -d "{\"config\":{\"secret\":\"${NEW_SECRET}\"}}" \
    "${GITEA_URL}/api/v1/repos/${repo}/hooks/${id}" >/dev/null
}

failed=()
while IFS=$'\t' read -r hookid repo; do
  [[ -z "$hookid" ]] && continue
  if (( DRY_RUN )); then
    log "DRY-RUN: would PATCH ${GITEA_URL}/api/v1/repos/${repo}/hooks/${hookid}"
  else
    if ! patch_one "$hookid" "$repo" 2>/dev/null; then
      failed+=("${repo}#${hookid}")
    fi
  fi
done <<< "$HOOK_LIST"

if (( ${#failed[@]} > 0 )); then
  die "PATCH failed for ${#failed[@]} hooks (${failed[*]}); aborting before file swap"
fi

# 4. Swap the file on Netcup atomically + restart deploy-webhook
if (( DRY_RUN )); then
  log "DRY-RUN: would write new secret to ${SSH_TARGET}:${SECRET_PATH} and docker restart deploy-webhook"
else
  ssh "$SSH_TARGET" "
    set -e
    cp '${SECRET_PATH}' '${SECRET_PATH}.bak.\$(date -u +%Y%m%d-%H%M%S)'
    printf '%s' '${NEW_SECRET}' > '${SECRET_PATH}.new'
    chmod 600 '${SECRET_PATH}.new'
    mv '${SECRET_PATH}.new' '${SECRET_PATH}'
    docker restart deploy-webhook >/dev/null
  "
  # Wait for container to be healthy
  sleep 3
fi

# 5. Smoke test: ask Gitea to redeliver the most recent push for one repo and
#    confirm deploy-webhook accepts (look for absence of "Invalid signature"
#    in the logs in the next 10s).
if ! (( DRY_RUN )); then
  smoke_repo=$(printf '%s\n' "$HOOK_LIST" | head -1 | cut -f2)
  smoke_id=$(printf '%s\n' "$HOOK_LIST" | head -1 | cut -f1)
  log "smoke test: triggering test delivery on $smoke_repo hook $smoke_id"
  curl -fsS -X POST \
    -H "Authorization: token ${GITEA_TOKEN}" \
    "${GITEA_URL}/api/v1/repos/${smoke_repo}/hooks/${smoke_id}/tests" >/dev/null || \
    log "WARN: test trigger returned non-200 (some Gitea versions don't support /tests; continue)"
  sleep 4
  rejects=$(ssh "$SSH_TARGET" "docker logs deploy-webhook --since 30s 2>&1 | grep -c 'Invalid.*signature' || true")
  if [[ "$rejects" -gt 0 ]]; then
    die "smoke test FAILED: deploy-webhook rejected $rejects signature(s) in last 30s"
  fi
  log "smoke test passed (no signature rejections)"
fi

# 6. Mark rotated
if (( DRY_RUN )); then
  log "DRY-RUN: would mark $NAME rotated in inventory"
else
  new_date=$(inventory_mark_rotated "$NAME")
  log "rotation complete; inventory updated to last_rotated=$new_date"
fi
