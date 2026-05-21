#!/usr/bin/env bash
# Phase 6: Cloudflare health checks + automatic DNS failover
set -euo pipefail

echo "=== Automatic Failover Setup ==="
echo ""
echo "This configures:"
echo "  1. Cloudflare Tunnel on this node (dormant)"
echo "  2. Health check script monitoring Netcup"
echo "  3. Auto-activation on Netcup failure"
echo ""

# --- Cloudflare Tunnel ---
echo "[1/3] Installing cloudflared..."
if ! command -v cloudflared &>/dev/null; then
  curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
  dpkg -i /tmp/cloudflared.deb
  rm /tmp/cloudflared.deb
fi

echo ""
echo "Create a new Cloudflare Tunnel for this failover node:"
echo "  cloudflared tunnel login"
echo "  cloudflared tunnel create backup-nas"
echo "  cloudflared tunnel route dns backup-nas <your-domain>"
echo ""
echo "Then configure /etc/cloudflared/config.yml with your tunnel credentials."
echo ""
read -p "Press Enter when Cloudflare Tunnel is configured (or skip for now)..."

# Disable tunnel by default (only activate on failover)
systemctl disable cloudflared 2>/dev/null || true
systemctl stop cloudflared 2>/dev/null || true

# --- Health check monitor ---
echo "[2/3] Setting up health check monitor..."

mkdir -p /opt/standby

cat > /opt/standby/health-monitor.sh << 'SCRIPT'
#!/usr/bin/env bash
# Monitor Netcup health and auto-activate failover
# Runs every minute via cron
set -euo pipefail

ENDPOINTS=(
  "https://rspace.online/api/health"
  "https://encryptid.jeffemmett.com/health"
)
FAIL_THRESHOLD=3
STATE_FILE="/tmp/failover-state"
FAIL_COUNT_FILE="/tmp/netcup-fail-count"

# Initialize
[ -f "$FAIL_COUNT_FILE" ] || echo "0" > "$FAIL_COUNT_FILE"
[ -f "$STATE_FILE" ] || echo "normal" > "$STATE_FILE"

CURRENT_STATE=$(cat "$STATE_FILE")
FAIL_COUNT=$(cat "$FAIL_COUNT_FILE")

# Check endpoints
ALL_OK=true
for endpoint in "${ENDPOINTS[@]}"; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$endpoint" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" != "200" ]; then
    ALL_OK=false
    echo "$(date): FAIL - $endpoint returned $HTTP_CODE" >> /var/log/health-monitor.log
  fi
done

if [ "$ALL_OK" = true ]; then
  # Reset fail counter
  echo "0" > "$FAIL_COUNT_FILE"

  # If we were in failover, check if we should deactivate
  if [ "$CURRENT_STATE" = "failover" ]; then
    echo "$(date): Netcup recovered. Manual deactivation required." >> /var/log/health-monitor.log
    # Don't auto-deactivate - requires manual intervention to re-sync data
  fi
else
  # Increment fail counter
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "$FAIL_COUNT" > "$FAIL_COUNT_FILE"

  if [ "$FAIL_COUNT" -ge "$FAIL_THRESHOLD" ] && [ "$CURRENT_STATE" = "normal" ]; then
    echo "$(date): FAILOVER TRIGGERED - $FAIL_COUNT consecutive failures" >> /var/log/health-monitor.log
    echo "failover" > "$STATE_FILE"
    /opt/standby/activate-failover.sh >> /var/log/failover-activation.log 2>&1
  fi
fi
SCRIPT
chmod +x /opt/standby/health-monitor.sh

# --- Failover alert ---
cat > /opt/standby/send-failover-alert.sh << 'SCRIPT'
#!/usr/bin/env bash
# Send failover alert email
SUBJECT="[FAILOVER] Netcup is DOWN - Backup NAS activated"
BODY="Failover activated at $(date).

Netcup failed $FAIL_THRESHOLD consecutive health checks.
Backup NAS is now serving critical services.

Services activated:
- Traefik (reverse proxy)
- rSpace Online
- EncryptID (auth)

Action required:
1. Investigate Netcup status
2. When recovered, run deactivate-failover.sh
3. Re-sync database replicas

Monitor: /var/log/failover-activation.log"

echo "$BODY" | mail -s "$SUBJECT" jeff@jeffemmett.com 2>/dev/null || \
  echo "WARNING: Could not send alert email. Check mail configuration."
SCRIPT
chmod +x /opt/standby/send-failover-alert.sh

# --- Cron ---
echo "[3/3] Installing health check cron..."
cat > /etc/cron.d/health-monitor << 'CRON'
# Check Netcup health every minute
* * * * * root /opt/standby/health-monitor.sh
CRON

echo ""
echo "=== Automatic failover setup complete ==="
echo ""
echo "Health monitor: checks Netcup every 60s"
echo "Fail threshold: $FAIL_THRESHOLD consecutive failures (~3 min) triggers failover"
echo "Logs: /var/log/health-monitor.log"
echo ""
echo "To test: /opt/standby/activate-failover.sh"
echo "To reset: /opt/standby/deactivate-failover.sh"
