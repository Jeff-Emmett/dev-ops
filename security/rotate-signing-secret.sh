#!/usr/bin/env bash
# Rotate SELF-GENERATED secrets (signing/JWT/APP secrets, KEY/SECRET pairs,
# admin passwords, internal tokens) — the class where WE choose the value, so
# the whole rotation can be automated end to end (unlike provider-minted keys).
#
# ⚠ BLAST RADIUS: rotating a token-signing secret (APP_SECRET, Directus
# KEY/SECRET, JWT secret) invalidates every active session / cached token for
# that service. That's a user-visible event — SCHEDULE + announce it. This
# script will NOT run without an explicit profile and is intended to be run by
# a human at a chosen time, not on an unattended cadence, for session-bearing
# secrets. (Internal-only tokens with no user sessions are safe anytime.)
#
# Usage: ./rotate-signing-secret.sh [--dry-run] <profile>
#
# Profile contract (bash file in ./signing-secret-profiles/):
#   INVENTORY_NAME="..."                  # for mark-rotated
#   GEN='openssl rand -hex 32'            # optional; generator for each target
#   # Each TARGET gets its OWN freshly-generated value:
#   TARGETS=( "<host>|<path>|<VAR>" )     # host=local|netcup; .env VAR to replace
#   RESTART=( "<host>|<cmd>" )            # recreate so the new value is read
#   VERIFY='curl -sf https://svc/health >/dev/null'   # optional, must exit 0
#
# Sequence: back up each file → replace each VAR with a fresh value → restart →
# verify → mark inventory. Backups (*.bak-pre-rotate-TS) enable manual revert
# (there's no "old value" to restore on the provider side — it's all local).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"
SSH_TARGET="${SSH_TARGET:-netcup-full}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--dry-run] <profile>

Available profiles:
$(ls "${SCRIPT_DIR}/signing-secret-profiles/"*.sh 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.sh$//; s/^/  - /' || echo '  (none yet)')
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
PROFILE_PATH="${SCRIPT_DIR}/signing-secret-profiles/${PROFILE_NAME}.sh"
[[ -f "$PROFILE_PATH" ]] || die "no profile at $PROFILE_PATH"
# shellcheck disable=SC1090
source "$PROFILE_PATH"
[[ -n "${INVENTORY_NAME:-}" ]] || die "profile missing INVENTORY_NAME"
{ [[ -n "${TARGETS+x}" ]] && (( ${#TARGETS[@]} > 0 )); } || die "profile defines no TARGETS"
GEN="${GEN:-openssl rand -hex 32}"

log "rotating $INVENTORY_NAME → ${#TARGETS[@]} signing target(s) (DRY_RUN=$DRY_RUN)"
log "NOTE: session-bearing secrets log out all users on restart — ensure this is scheduled."

replace_var() {  # host path var newval
  local host="$1" path="$2" var="$3" val="$4"
  local sh="set -e; [ -f '$path' ] || { echo 'MISSING:$path' >&2; exit 9; }; cp -p '$path' '$path.bak-pre-rotate-\$(date -u +%Y%m%d-%H%M%S)'; tmp=\$(mktemp); awk -v v=\"\$NEWVAL\" 'BEGIN{d=0}/^${var}=/{print \"${var}=\" v; d=1; next}{print}END{if(!d)exit 8}' '$path' > \"\$tmp\" && mv \"\$tmp\" '$path' || { echo 'NOVAR:${var}' >&2; exit 8; }; chmod 600 '$path'"
  if (( DRY_RUN )); then log "DRY-RUN: [$host] would set $var=<fresh> in $path (backup first)"; return 0; fi
  if [[ "$host" == "local" ]]; then NEWVAL="$val" bash -c "$sh"
  else NEWVAL="$val" ssh "$SSH_TARGET" "NEWVAL='$val' bash -s" <<<"$sh"; fi
}

for spec in "${TARGETS[@]}"; do
  IFS='|' read -r host path var <<<"$spec"
  if (( DRY_RUN )); then NEWVAL="dry"; else NEWVAL="$(eval "$GEN")"; fi
  if replace_var "$host" "$path" "$var" "$NEWVAL"; then log "rotated: [$host] $var in $path"
  else die "failed to set $var in $path — backups exist; NOT marking rotated"; fi
done

for spec in "${RESTART[@]:-}"; do
  [[ -z "$spec" ]] && continue
  IFS='|' read -r host cmd <<<"$spec"
  if (( DRY_RUN )); then log "DRY-RUN: [$host] would run: $cmd"; continue; fi
  if [[ "$host" == "local" ]]; then bash -c "$cmd" >/dev/null 2>&1 || log "WARNING: restart failed: $cmd"
  else ssh "$SSH_TARGET" "$cmd" >/dev/null 2>&1 || log "WARNING: restart failed: $cmd"; fi
  log "restarted: [$host] $cmd"
done

if [[ -n "${VERIFY:-}" ]]; then
  if (( DRY_RUN )); then log "DRY-RUN: would verify with: $VERIFY"
  elif bash -c "$VERIFY"; then log "verify passed ✓"
  else die "verify FAILED after rotation — restore *.bak-pre-rotate-* and recreate. Service may be down."; fi
fi

if (( DRY_RUN )); then log "DRY-RUN complete for $INVENTORY_NAME (no changes)"
else TODAY=$(inventory_mark_rotated "$INVENTORY_NAME"); log "inventory_mark_rotated $INVENTORY_NAME → $TODAY ✓"; fi
