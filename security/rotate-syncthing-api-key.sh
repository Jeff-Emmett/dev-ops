#!/usr/bin/env bash
# Rotate Syncthing REST/GUI API key(s). Two independent instances, two
# inventory entries:
#   - syncthing-local-api-key   → local WSL2, user-systemd, config at
#                                 ~/.local/state/syncthing/config.xml
#   - syncthing-netcup-api-key  → Netcup Docker container `syncthing`,
#                                 config at /opt/syncthing/config/config.xml
#
# Usage: rotate-syncthing-api-key.sh [--dry-run] <local|netcup|both>
#
# The API key only gates the Syncthing Web GUI + REST API. Verified
# 2026-05-15: no scripted consumers on either host, so rotation just
# re-auths the GUI (and any monitoring tool you've pointed at /rest/*).
#
# Per-target sequence:
#   1. Generate a new 32-char url-safe key.
#   2. Back up config.xml, replace <apikey>OLD</apikey> with the new one
#      (Python regex — robust vs sed for XML; scp-edit-scp for netcup to
#      avoid ssh+docker quoting layers).
#   3. Restart Syncthing (systemctl --user for local; docker restart for
#      netcup) so it reloads config.
#   4. Smoke test: GET /rest/system/ping with the new key → {"ping":"pong"}.
#      Local: direct on 127.0.0.1:8384. Netcup: in-container (GUI port is
#      not host-mapped) via the container's own wget/curl if present,
#      else fall back to "container Up + config has new key".
#   5. inventory_mark_rotated for that target's entry.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

TARGET=""
while (( $# > 0 )); do
  case "$1" in
    --dry-run|-n) DRY_RUN=1; shift ;;
    --help|-h) echo "Usage: $(basename "$0") [--dry-run] <local|netcup|both>"; exit 0 ;;
    local|netcup|both) TARGET="$1"; shift ;;
    *) die "unknown arg: $1 (want local|netcup|both)" ;;
  esac
done
[[ -n "$TARGET" ]] || die "specify target: local | netcup | both"

SSH_TARGET="${SSH_TARGET:-netcup-full}"
LOCAL_CFG="${LOCAL_CFG:-${HOME}/.local/state/syncthing/config.xml}"
NETCUP_CFG="${NETCUP_CFG:-/opt/syncthing/config/config.xml}"

gen_key() { openssl rand -base64 24 | tr -d '/+=' | cut -c1-32; }

# Replace <apikey>…</apikey> in a local file via Python (regex, single match).
rewrite_local() {
  local file="$1" newkey="$2"
  NEWKEY="$newkey" python3 - "$file" <<'PY'
import os, re, sys, pathlib
p = pathlib.Path(sys.argv[1])
t = p.read_text()
t, n = re.subn(r'<apikey>[^<]*</apikey>', f'<apikey>{os.environ["NEWKEY"]}</apikey>', t, count=1)
assert n == 1, f"expected exactly 1 <apikey> element, got {n}"
p.write_text(t)
PY
}

rotate_local() {
  log "rotating syncthing-local-api-key (DRY_RUN=$DRY_RUN)"
  [[ -f "$LOCAL_CFG" ]] || die "local config not found: $LOCAL_CFG"
  if (( DRY_RUN )); then
    log "DRY-RUN: would gen key, rewrite $LOCAL_CFG, systemctl --user restart syncthing, ping :8384"
    return 0
  fi
  local newkey ts
  newkey=$(gen_key)
  ts=$(date -u +%Y%m%d-%H%M%S)
  cp -p "$LOCAL_CFG" "${LOCAL_CFG}.bak-pre-rotate-${ts}"
  rewrite_local "$LOCAL_CFG" "$newkey"
  log "local config.xml rewritten (backup .bak-pre-rotate-${ts})"
  systemctl --user restart syncthing
  sleep 4
  local pong
  pong=$(curl -sf -H "X-API-Key: $newkey" http://127.0.0.1:8384/rest/system/ping 2>/dev/null || true)
  if [[ "$pong" != *'"pong"'* ]]; then
    die "local smoke test failed (ping → '${pong:-<none>}'). Restore ${LOCAL_CFG}.bak-pre-rotate-${ts} + systemctl --user restart syncthing"
  fi
  log "local smoke test: /rest/system/ping → pong ✓"
  inventory_mark_rotated "syncthing-local-api-key" >/dev/null
  log "inventory_mark_rotated syncthing-local-api-key"
}

rotate_netcup() {
  log "rotating syncthing-netcup-api-key (DRY_RUN=$DRY_RUN)"
  if (( DRY_RUN )); then
    log "DRY-RUN: would scp $NETCUP_CFG, rewrite <apikey>, scp back, docker restart syncthing, in-container ping"
    return 0
  fi
  local newkey ts tmp_in tmp_out
  newkey=$(gen_key)
  ts=$(date -u +%Y%m%d-%H%M%S)
  tmp_in=$(mktemp); tmp_out=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f $tmp_in $tmp_out" RETURN
  scp -q "$SSH_TARGET:$NETCUP_CFG" "$tmp_in"
  ssh "$SSH_TARGET" "cp -p $NETCUP_CFG ${NETCUP_CFG}.bak-pre-rotate-${ts}"

  NEWKEY="$newkey" python3 - "$tmp_in" "$tmp_out" <<'PY'
import os, re, sys, pathlib
src, dst = sys.argv[1], sys.argv[2]
t = pathlib.Path(src).read_text()
t, n = re.subn(r'<apikey>[^<]*</apikey>', f'<apikey>{os.environ["NEWKEY"]}</apikey>', t, count=1)
assert n == 1, f"expected exactly 1 <apikey> element, got {n}"
pathlib.Path(dst).write_text(t)
PY

  scp -q "$tmp_out" "$SSH_TARGET:$NETCUP_CFG"
  log "netcup config.xml rewritten (backup .bak-pre-rotate-${ts})"
  ssh "$SSH_TARGET" "docker restart syncthing" >/dev/null
  sleep 5

  # GUI port isn't host-mapped; smoke-test from inside the container.
  local result
  result=$(ssh "$SSH_TARGET" "
    if docker exec syncthing sh -c 'command -v wget' >/dev/null 2>&1; then
      docker exec syncthing wget -qO- --header='X-API-Key: $newkey' http://127.0.0.1:8384/rest/system/ping 2>/dev/null
    elif docker exec syncthing sh -c 'command -v curl' >/dev/null 2>&1; then
      docker exec syncthing curl -sf -H 'X-API-Key: $newkey' http://127.0.0.1:8384/rest/system/ping 2>/dev/null
    else
      echo NO_HTTP_CLIENT
    fi
  " 2>/dev/null | tr -d '\r')

  if [[ "$result" == *'"pong"'* ]]; then
    log "netcup smoke test: in-container /rest/system/ping → pong ✓"
  elif [[ "$result" == "NO_HTTP_CLIENT" ]]; then
    # Fallback: container Up + config has the new key.
    local up cfgok
    up=$(ssh "$SSH_TARGET" "docker ps --format '{{.Names}}|{{.Status}}' | grep '^syncthing|' " 2>/dev/null | tr -d '\r')
    cfgok=$(ssh "$SSH_TARGET" "grep -c '<apikey>${newkey}</apikey>' $NETCUP_CFG" 2>/dev/null | tr -d '\r')
    if [[ "$up" == *"|Up"* && "$cfgok" == "1" ]]; then
      log "netcup smoke (fallback): container Up + config has new key ✓ (no in-container HTTP client to ping)"
    else
      die "netcup smoke fallback failed (up='$up' cfgok='$cfgok'). Restore ${NETCUP_CFG}.bak-pre-rotate-${ts}, docker restart syncthing"
    fi
  else
    die "netcup smoke test failed (ping → '${result:-<none>}'). Restore ${NETCUP_CFG}.bak-pre-rotate-${ts}, docker restart syncthing"
  fi

  inventory_mark_rotated "syncthing-netcup-api-key" >/dev/null
  log "inventory_mark_rotated syncthing-netcup-api-key"
}

case "$TARGET" in
  local)  rotate_local ;;
  netcup) rotate_netcup ;;
  both)   rotate_local; rotate_netcup ;;
esac

log "rotation complete ($TARGET)"
