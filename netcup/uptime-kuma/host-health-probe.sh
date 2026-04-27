#!/usr/bin/env bash
# Aggregated host health probe for Uptime Kuma.
#
# Runs every 5 min on Netcup. Performs three local checks and pushes a
# heartbeat to a Kuma push monitor only when ALL pass. If any check fails,
# pushes status=down with a message — Kuma alerts via the Mailcow Email
# Alerts channel.
#
# Push token is loaded from /etc/uptime-kuma-push.env (mode 600, root-only).
# This file is NOT committed; it lives only on the server.

set -u

ENV_FILE="/etc/uptime-kuma-push.env"
if [[ ! -r "$ENV_FILE" ]]; then
  echo "missing $ENV_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if [[ -z "${HOST_HEALTH_PUSH_TOKEN:-}" ]]; then
  echo "HOST_HEALTH_PUSH_TOKEN unset" >&2
  exit 1
fi

# Reach Kuma through local Traefik on loopback — Cloudflare Access protects
# the external edge, not the local 80 binding, so loopback pushes go through
# without auth. Container IPs change on recreate; this Host header is stable.
KUMA_HOST="status.jeffemmett.com"
KUMA_BASE="http://127.0.0.1"

status="up"
msgs=()

# 1. Disk free — alert if root partition >85% used
disk_used_pct=$(df --output=pcent / | tail -1 | tr -dc '0-9')
if (( disk_used_pct > 85 )); then
  status="down"
  msgs+=("disk:${disk_used_pct}%")
fi

# 2. Memory — alert if BOTH RAM is >95% used AND swap is >95% used
#    (either alone is normal on this server; the combo means real pressure)
read -r mem_total mem_used <<< "$(free -m | awk '/^Mem:/ {print $2, $3}')"
read -r swap_total swap_used <<< "$(free -m | awk '/^Swap:/ {print $2, $3}')"
mem_pct=$(( mem_used * 100 / mem_total ))
swap_pct=0
if (( swap_total > 0 )); then swap_pct=$(( swap_used * 100 / swap_total )); fi
if (( mem_pct > 95 && swap_pct > 95 )); then
  status="down"
  msgs+=("mem:${mem_pct}%,swap:${swap_pct}%")
fi

# 3. Container count floor — alert if running container count drops more
#    than 10% below recorded baseline (catches mass-exit events).
running_count=$(docker ps -q | wc -l)
baseline_file="/var/lib/uptime-kuma-host-probe/container-baseline"
mkdir -p "$(dirname "$baseline_file")"
if [[ -f "$baseline_file" ]]; then
  baseline=$(cat "$baseline_file")
  threshold=$(( baseline * 90 / 100 ))
  if (( running_count < threshold )); then
    status="down"
    msgs+=("containers:${running_count}<baseline:${baseline}")
  fi
  # Slowly raise baseline if current count is higher (services added)
  if (( running_count > baseline )); then
    echo "$running_count" > "$baseline_file"
  fi
else
  echo "$running_count" > "$baseline_file"
fi

# Compose ping URL
msg="OK"
[[ ${#msgs[@]} -gt 0 ]] && msg=$(IFS=, ; echo "${msgs[*]}")

url="${KUMA_BASE}/api/push/${HOST_HEALTH_PUSH_TOKEN}?status=${status}&msg=${msg}"

curl -fsS -m 10 -H "Host: ${KUMA_HOST}" "$url" >/dev/null
exit $?
