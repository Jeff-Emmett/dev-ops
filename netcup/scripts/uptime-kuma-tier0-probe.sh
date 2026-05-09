#!/bin/bash
# Pushes Tier 0 mem-saturation status to Uptime Kuma every 5 min.
# Status DOWN if any Tier 0 container is using > 90% of its mem_limit
# (which is what triggered the CrowdSec → bouncer fail-deny outage 2026-05-09).
#
# Push token: $TIER0_SATURATION_PUSH_TOKEN in /etc/uptime-kuma-push.env (mode 600).
# Setup walkthrough: dev-ops/netcup/uptime-kuma/tier0-saturation-monitor.md.

set -uo pipefail

ENV_FILE="/etc/uptime-kuma-push.env"
THRESHOLD_PCT=90

[ -f "$ENV_FILE" ] || { logger -t tier0-probe "missing $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
. "$ENV_FILE"
[ -n "${TIER0_SATURATION_PUSH_TOKEN:-}" ] || { logger -t tier0-probe "TIER0_SATURATION_PUSH_TOKEN unset"; exit 1; }

# Tier 0 list (mirror of enforce-oom-tiers.sh — keep in sync)
TIER0_NAMES=(traefik infisical gitea uptime-kuma restic crowdsec bouncer-traefik)
TIER0_PATTERN='^mailcowdockerized-(postfix|dovecot|mysql|rspamd|sogo|redis|nginx|php-fpm)-mailcow-1$'

# Build full list including running mailcow matches
declare -a TIER0=("${TIER0_NAMES[@]}")
while IFS= read -r c; do TIER0+=("$c"); done < <(docker ps --format '{{.Names}}' | grep -E "$TIER0_PATTERN" || true)

worst_pct=0
worst_name=""
report=""
checked=0

for c in "${TIER0[@]}"; do
  # mem_limit in bytes; usage in MiB from `docker stats`
  mem_limit_bytes=$(docker inspect -f '{{.HostConfig.Memory}}' "$c" 2>/dev/null) || continue
  [ "$mem_limit_bytes" = "0" ] && continue   # unlimited container, skip
  mem_used_str=$(docker stats --no-stream --format '{{.MemUsage}}' "$c" 2>/dev/null) || continue
  # MemUsage format: "215.2MiB / 1GiB" — numfmt wants "Mi" not "MiB", strip trailing B
  used_part=$(echo "$mem_used_str" | awk '{print $1}')
  used_part="${used_part%B}"
  used_bytes=$(numfmt --from=iec-i "$used_part" 2>/dev/null) || continue
  pct=$(awk -v u="$used_bytes" -v l="$mem_limit_bytes" 'BEGIN { printf "%d", (u / l) * 100 }')
  checked=$((checked + 1))
  report="${report}${c}=${pct}% "
  if [ "$pct" -gt "$worst_pct" ]; then
    worst_pct=$pct
    worst_name=$c
  fi
done

if [ "$worst_pct" -ge "$THRESHOLD_PCT" ]; then
  status="down"
  msg="${worst_name} at ${worst_pct}% of mem_limit (threshold ${THRESHOLD_PCT}%); ${checked} tier0 containers checked"
else
  status="up"
  msg="all tier0 ok (worst: ${worst_name} ${worst_pct}%); ${checked} checked"
fi

# Push to Uptime Kuma via Traefik loopback (no CF Access on internal route)
push_url="http://127.0.0.1/api/push/${TIER0_SATURATION_PUSH_TOKEN}?status=${status}&msg=$(printf '%s' "$msg" | sed 's/ /%20/g; s/(/%28/g; s/)/%29/g; s/=/%3D/g')&ping="
curl -sS --max-time 5 -H 'Host: status.jeffemmett.com' "$push_url" -o /dev/null

logger -t tier0-probe "status=$status worst=$worst_name@${worst_pct}% checked=$checked"
echo "$(date -Iseconds) status=$status worst=$worst_name@${worst_pct}% (${report})"
