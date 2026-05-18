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

# Retry before declaring DOWN. The host runs ~389 containers with swap
# pinned at 100%; periodic thrash spikes can stall a single request past
# an 8s timeout even though Vaultwarden itself is healthy and real clients
# (browser/CF retries, longer timeouts) never notice. A single-shot probe
# turned those micro-stalls into alert-email spam. Requiring all attempts
# to fail means a genuine outage (>~25s unreachable) still alerts within
# the 5-min cycle, but a transient blip recovers on retry and stays UP.
MAX_ATTEMPTS=3
PER_TIMEOUT=5
RETRY_GAP=4

STATUS="down"
MSG=""
PING_MS=0

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  RAW=$(curl -fsS --max-time "$PER_TIMEOUT" \
          -H "Host: ${VW_HOST}" \
          -o /tmp/.vw-probe.out \
          -w "%{http_code} %{time_total}" \
          "${URL}" 2>/dev/null) || RAW="000 0"

  HTTP_CODE=${RAW%% *}
  TIME_TOTAL=${RAW#* }
  PING_MS=$(awk -v t="$TIME_TOTAL" 'BEGIN { printf "%d", t*1000 }')

  if [[ "$HTTP_CODE" == "200" ]]; then
    # /alive returns a JSON-quoted ISO 8601 timestamp like "2026-05-14T20:42:00Z".
    # Don't parse — just confirm it looks like a timestamp.
    BODY=$(head -c 80 /tmp/.vw-probe.out 2>/dev/null)
    if [[ "$BODY" == *"T"*"Z"* ]]; then
      STATUS="up"
      MSG="alive ok ${PING_MS}ms (try ${attempt}/${MAX_ATTEMPTS})"
      break
    fi
    MSG="alive bad body: ${BODY:0:30} (try ${attempt}/${MAX_ATTEMPTS})"
  else
    MSG="alive http=${HTTP_CODE} (try ${attempt}/${MAX_ATTEMPTS})"
  fi

  [[ "$attempt" -lt "$MAX_ATTEMPTS" ]] && sleep "$RETRY_GAP"
done

rm -f /tmp/.vw-probe.out

# Push to Kuma via Traefik loopback (same pattern as other host probes).
# Use --data-urlencode so msg/pipes don't trip CrowdSec's WAF.
curl -fsS --max-time 8 -H 'Host: status.jeffemmett.com' \
  -G "http://127.0.0.1/api/push/${VAULTWARDEN_PUSH_TOKEN}" \
  --data-urlencode "status=${STATUS}" \
  --data-urlencode "msg=${MSG}" \
  --data-urlencode "ping=${PING_MS}" \
  -o /dev/null
