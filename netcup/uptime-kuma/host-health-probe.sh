#!/usr/bin/env bash
# Aggregated host health probe for Uptime Kuma.
#
# Runs every 2 min on Netcup. Performs three local checks and pushes a
# heartbeat to a Kuma push monitor. Status reflects whether all checks
# pass, but the heartbeat itself is sent on every run — under heavy host
# load, getting *some* signal to Kuma matters more than waiting on slow
# diagnostics, so each check is wrapped in a short timeout and a hang
# degrades to a warning rather than suppressing the heartbeat.
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
if disk_used_pct=$(timeout 5 df --output=pcent / 2>/dev/null | tail -1 | tr -dc '0-9'); then
  if [[ -n "$disk_used_pct" ]] && (( disk_used_pct > 85 )); then
    status="down"
    msgs+=("disk:${disk_used_pct}%")
  fi
else
  msgs+=("disk:timeout")
fi

# 2. Memory — alert if BOTH RAM is >95% used AND swap is >95% used
#    (either alone is normal on this server; the combo means real pressure)
if mem_line=$(timeout 5 free -m 2>/dev/null); then
  read -r mem_total mem_used <<< "$(echo "$mem_line" | awk '/^Mem:/ {print $2, $3}')"
  read -r swap_total swap_used <<< "$(echo "$mem_line" | awk '/^Swap:/ {print $2, $3}')"
  mem_pct=$(( mem_used * 100 / mem_total ))
  swap_pct=0
  if (( swap_total > 0 )); then swap_pct=$(( swap_used * 100 / swap_total )); fi
  if (( mem_pct > 95 && swap_pct > 95 )); then
    status="down"
    msgs+=("mem:${mem_pct}%,swap:${swap_pct}%")
  fi
else
  msgs+=("mem:timeout")
fi

# 3. Container count floor — alert if running container count drops more
#    than 10% below recorded baseline (catches mass-exit events).
#    `docker ps` can hang under heavy IO load, so cap it.
if running_count=$(timeout 10 docker ps -q 2>/dev/null | wc -l); then
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
else
  msgs+=("docker:timeout")
fi

# Compose ping URL
msg="OK"
[[ ${#msgs[@]} -gt 0 ]] && msg=$(IFS=, ; echo "${msgs[*]}")

url="${KUMA_BASE}/api/push/${HOST_HEALTH_PUSH_TOKEN}?status=${status}&msg=${msg}"

# Short connect/total timeouts so a single push can't run past the next tick.
curl -fsS --connect-timeout 5 -m 15 -H "Host: ${KUMA_HOST}" "$url" >/dev/null
exit $?
