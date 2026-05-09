#!/usr/bin/env bash
# FalkorDB liveness + basic stats probe for Uptime Kuma.
#
# Runs every 5 min on Netcup (uptime-kuma-falkordb-probe.timer). Pings
# FalkorDB inside the container, then queries node + edge counts on the
# claude_memory graph. Pushes status + msg to a Kuma push monitor.
#
# Setup (one-shot):
#   1. Create push monitor in Uptime Kuma UI named "FalkorDB (Netcup)".
#      Copy its token.
#   2. Append to /etc/uptime-kuma-push.env:
#        FALKORDB_PUSH_TOKEN=<token-from-kuma>
#   3. Install this script + the .timer + .service files (see README).
#   4. systemctl daemon-reload && systemctl enable --now uptime-kuma-falkordb-probe.timer
#
# Why a heartbeat-style probe rather than HTTP: FalkorDB is Redis protocol,
# not HTTP. Kuma's TCP monitor would only verify the port answers; this
# script also confirms auth works and a real graph query returns sane data.

set -u

ENV_FILE="/etc/uptime-kuma-push.env"
if [[ ! -r "$ENV_FILE" ]]; then
  echo "missing $ENV_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if [[ -z "${FALKORDB_PUSH_TOKEN:-}" ]]; then
  echo "FALKORDB_PUSH_TOKEN unset in $ENV_FILE" >&2
  exit 1
fi

# Pull FalkorDB password from the deployed compose .env (mode 600, root-only).
FALKORDB_ENV="/opt/apps/falkordb/.env"
if [[ ! -r "$FALKORDB_ENV" ]]; then
  echo "missing $FALKORDB_ENV" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$FALKORDB_ENV"

if [[ -z "${FALKORDB_PASSWORD:-}" ]]; then
  echo "FALKORDB_PASSWORD unset in $FALKORDB_ENV" >&2
  exit 1
fi

STATUS="up"
MSG=""

# Ping
if ! PING_OUT=$(timeout 5 docker exec falkordb redis-cli -a "$FALKORDB_PASSWORD" --no-auth-warning ping 2>&1); then
  STATUS="down"
  MSG="ping failed: $PING_OUT"
elif [[ "$PING_OUT" != "PONG" ]]; then
  STATUS="down"
  MSG="ping returned: $PING_OUT"
else
  # Memory usage (informational, doesn't downgrade status)
  MEM=$(timeout 5 docker exec falkordb redis-cli -a "$FALKORDB_PASSWORD" --no-auth-warning INFO memory 2>/dev/null \
        | awk -F: '/^used_memory_human:/ {gsub(/\r/, ""); print $2}')

  # Graph stats — try a known graph if present
  GRAPHS=$(timeout 5 docker exec falkordb redis-cli -a "$FALKORDB_PASSWORD" --no-auth-warning GRAPH.LIST 2>/dev/null \
           | grep -v '^$' | wc -l)

  MSG="ping ok | mem ${MEM:-?} | graphs ${GRAPHS:-0}"
fi

# Push to Kuma
PUSH_URL="http://127.0.0.1/api/push/${FALKORDB_PUSH_TOKEN}?status=${STATUS}&msg=$(printf '%s' "$MSG" | sed 's/ /+/g')&ping="
curl -fsS --max-time 8 -H 'Host: status.jeffemmett.com' "$PUSH_URL" -o /dev/null
