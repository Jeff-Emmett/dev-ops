#!/usr/bin/env bash
# Vaultwarden liveness probe for Uptime Kuma.
#
# Runs every 5 min on Netcup (uptime-kuma-vaultwarden-probe.timer).
# Hits VW's /alive endpoint via Traefik loopback (so this works regardless
# of Cloudflare Access policies that may sit in front of the public URL).
# /alive returns a UNIX timestamp + 200 OK when Vaultwarden is healthy.
#
# Setup (one-shot):
#   1. Create push monitor in Uptime Kuma UI named "Vaultwarden (Netcup)".
#      Copy its push token.
#   2. Append to /etc/uptime-kuma-push.env (mode 600, root-only):
#        VAULTWARDEN_PUSH_TOKEN=<token-from-kuma>
#   3. Install: see uptime-kuma-vaultwarden-probe.service / .timer.
#   4. systemctl daemon-reload && systemctl enable --now uptime-kuma-vaultwarden-probe.timer

set -u

ENV_FILE="/etc/uptime-kuma-push.env"
if [[ ! -r "$ENV_FILE" ]]; then
  echo "missing $ENV_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if [[ -z "${VAULTWARDEN_PUSH_TOKEN:-}" ]]; then
  echo "VAULTWARDEN_PUSH_TOKEN unset in $ENV_FILE" >&2
  exit 1
fi

VW_HOST="passwords.jeffemmett.com"
URL="http://127.0.0.1/alive"

STATUS="up"
MSG=""

# Measure latency in ms (curl -w writes elapsed seconds).
RAW=$(curl -fsS --max-time 8 \
        -H "Host: ${VW_HOST}" \
        -o /tmp/.vw-probe.out \
        -w "%{http_code} %{time_total}" \
        "${URL}" 2>/dev/null) || RAW="000 0"

HTTP_CODE=${RAW%% *}
TIME_TOTAL=${RAW#* }
PING_MS=$(awk -v t="$TIME_TOTAL" 'BEGIN { printf "%d", t*1000 }')

if [[ "$HTTP_CODE" != "200" ]]; then
  STATUS="down"
  MSG="alive http=${HTTP_CODE}"
else
  # /alive returns a JSON-quoted ISO 8601 timestamp like "2026-05-14T20:42:00Z".
  # Don't try to parse — just confirm it looks like a timestamp.
  BODY=$(head -c 80 /tmp/.vw-probe.out 2>/dev/null)
  if [[ "$BODY" == *"T"*"Z"* ]]; then
    MSG="alive ok ${PING_MS}ms"
  else
    STATUS="down"
    MSG="alive bad body: ${BODY:0:30}"
  fi
fi

rm -f /tmp/.vw-probe.out

# Push to Kuma via Traefik loopback (same pattern as other host probes).
# Use --data-urlencode so msg/pipes don't trip CrowdSec's WAF.
curl -fsS --max-time 8 -H 'Host: status.jeffemmett.com' \
  -G "http://127.0.0.1/api/push/${VAULTWARDEN_PUSH_TOKEN}" \
  --data-urlencode "status=${STATUS}" \
  --data-urlencode "msg=${MSG}" \
  --data-urlencode "ping=${PING_MS}" \
  -o /dev/null
