#!/usr/bin/env bash
# Generic propagation for a provider-minted secret (external API key, token).
#
# THE MINT STEP IS ALWAYS MANUAL — no provider lets you mint a key without a
# human in their console. This script automates EVERYTHING after that: it takes
# the freshly-minted value and fans it out to every consumer (local + Netcup
# .env files / single-value files), restarts the long-lived consumers, runs an
# optional smoke test, and marks the inventory. It is the rotate-gemini pattern
# generalized and driven by a per-secret profile.
#
# Usage:
#   ./propagate-external-key.sh [--dry-run] --key-file /path/to/new <profile>
#   printf '%s' "$NEWVAL" | ./propagate-external-key.sh [--dry-run] <profile>
#
# The new value is read from stdin or --key-file ONLY (never argv — that leaks
# into shell history / ps / logs). Profiles live in ./external-key-profiles/.
#
# Profile contract (a bash file that sets):
#   INVENTORY_NAME            inventory entry name (for mark-rotated)
#   KEY_REGEX                 (optional) anchored ERE the new value must match
#   # Consumers: one line per consumer in the CONSUMERS array, "spec":
#   #   <host>|<path>|<var>
#   #     host = local | netcup
#   #     var  = __FILE__   → path is a single-value file (whole content = key)
#   #            VARNAME     → path is an .env; replace ^VARNAME=... line
#   CONSUMERS=( "local|/home/jeffe/.secrets/private/foo|__FILE__"
#               "netcup|/opt/secrets/foo/.env|FOO_KEY" )
#   # Optional: containers/commands to restart after propagation:
#   RESTART=( "netcup|cd /opt/apps/foo && docker compose up -d" )
#   # Optional smoke test: a command with $NEW in env that must exit 0.
#   #   SMOKE='curl -sf -H "Authorization: Bearer $NEW" https://api.foo/whoami >/dev/null'

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"
SSH_TARGET="${SSH_TARGET:-netcup-full}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--dry-run] (--key-file PATH | stdin) <profile>

Available profiles:
$(ls "${SCRIPT_DIR}/external-key-profiles/"*.sh 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.sh$//; s/^/  - /' || echo '  (none yet)')
USAGE
}

PROFILE_NAME="" KEY_FILE_ARG=""
while (( $# > 0 )); do
  case "$1" in
    --dry-run|-n)  DRY_RUN=1; shift ;;
    --key-file|-f) KEY_FILE_ARG="${2:?--key-file needs a path}"; shift 2 ;;
    --help|-h)     usage; exit 0 ;;
    --*)           die "unknown flag: $1" ;;
    *)             PROFILE_NAME="$1"; shift ;;
  esac
done
[[ -z "$PROFILE_NAME" ]] && { usage; exit 1; }
PROFILE_PATH="${SCRIPT_DIR}/external-key-profiles/${PROFILE_NAME}.sh"
[[ -f "$PROFILE_PATH" ]] || die "no profile at $PROFILE_PATH"
# shellcheck disable=SC1090
source "$PROFILE_PATH"
[[ -n "${INVENTORY_NAME:-}" ]] || die "profile missing INVENTORY_NAME"
{ [[ -n "${CONSUMERS+x}" ]] && (( ${#CONSUMERS[@]} > 0 )); } || die "profile defines no CONSUMERS"

# Read new value (stdin or --key-file), never argv.
if [[ -n "$KEY_FILE_ARG" ]]; then
  [[ -f "$KEY_FILE_ARG" ]] || die "key file not found: $KEY_FILE_ARG"
  NEW="$(tr -d '\r\n' < "$KEY_FILE_ARG")"
else
  [[ -t 0 ]] && die "no key on stdin and no --key-file (refusing to prompt on a TTY)"
  NEW="$(tr -d '\r\n')"
fi
[[ -n "$NEW" ]] || die "empty new value"
if [[ -n "${KEY_REGEX:-}" && ! "$NEW" =~ $KEY_REGEX ]]; then
  die "new value failed KEY_REGEX ($KEY_REGEX); got ${#NEW} chars"
fi
log "propagating $INVENTORY_NAME → ${#CONSUMERS[@]} consumer(s) (DRY_RUN=$DRY_RUN, value not logged)"

# One consumer: back up, then either overwrite a single-value file or sed an
# .env line. Runs locally or over ssh depending on host.
apply_one() {
  local host="$1" path="$2" var="$3"
  local sh
  if [[ "$var" == "__FILE__" ]]; then
    sh="set -e; [ -f '$path' ] && cp -p '$path' '$path.bak-pre-rotate-\$(date -u +%Y%m%d-%H%M%S)' || mkdir -p \"\$(dirname '$path')\"; umask 077; printf '%s' \"\$NEWVAL\" > '$path'; chmod 600 '$path'"
  else
    sh="set -e; [ -f '$path' ] || { echo 'MISSING:$path' >&2; exit 9; }; cp -p '$path' '$path.bak-pre-rotate-\$(date -u +%Y%m%d-%H%M%S)'; tmp=\$(mktemp); awk -v v=\"\$NEWVAL\" 'BEGIN{done=0} /^${var}=/{print \"${var}=\" v; done=1; next} {print} END{if(!done) exit 8}' '$path' > \"\$tmp\" && mv \"\$tmp\" '$path' || { echo 'NOVAR:${var}:$path' >&2; exit 8; }; chmod 600 '$path'"
  fi
  if (( DRY_RUN )); then
    log "DRY-RUN: [$host] would update $var in $path (with timestamped backup)"
    return 0
  fi
  if [[ "$host" == "local" ]]; then
    NEWVAL="$NEW" bash -c "$sh"
  else
    NEWVAL="$NEW" ssh "$SSH_TARGET" "NEWVAL='$NEW' bash -s" <<<"$sh"
  fi
}

FAILED=0
for spec in "${CONSUMERS[@]}"; do
  IFS='|' read -r host path var <<<"$spec"
  if apply_one "$host" "$path" "$var"; then
    log "updated: [$host] $path ($var)"
  else
    log "WARNING: failed to update [$host] $path ($var) — fix manually"; FAILED=1
  fi
done

# Restart long-lived consumers.
for spec in "${RESTART[@]:-}"; do
  [[ -z "$spec" ]] && continue
  IFS='|' read -r host cmd <<<"$spec"
  if (( DRY_RUN )); then log "DRY-RUN: [$host] would run: $cmd"; continue; fi
  if [[ "$host" == "local" ]]; then bash -c "$cmd" >/dev/null 2>&1 || log "WARNING: restart failed: $cmd"
  else ssh "$SSH_TARGET" "$cmd" >/dev/null 2>&1 || log "WARNING: restart failed on $SSH_TARGET: $cmd"; fi
  log "restarted: [$host] $cmd"
done

# Optional smoke test.
if [[ -n "${SMOKE:-}" ]]; then
  if (( DRY_RUN )); then
    log "DRY-RUN: would smoke-test with: ${SMOKE}"
  elif NEW="$NEW" bash -c "$SMOKE"; then
    log "smoke test passed ✓"
  else
    die "smoke test FAILED — the new value may be wrong or a consumer is stale. Old key NOT yet revoked; investigate before revoking."
  fi
fi

(( FAILED )) && die "one or more consumers failed to update — NOT marking rotated. Fix + re-run."

if (( DRY_RUN )); then
  log "DRY-RUN complete for $INVENTORY_NAME (no changes)"
else
  TODAY=$(inventory_mark_rotated "$INVENTORY_NAME")
  log "inventory_mark_rotated $INVENTORY_NAME → $TODAY"
  log "propagation complete ✓  — now REVOKE the OLD key in the provider console."
fi
