#!/usr/bin/env bash
# Phase 5: Deploy warm standby containers for critical services
set -euo pipefail

echo "=== Warm Standby Setup ==="
echo "Deploying standby containers for critical services."
echo "These containers start in stopped state and activate on failover."
echo ""

# --- Traefik standby ---
echo "[1/3] Setting up Traefik standby..."
mkdir -p /opt/standby/traefik/{config,certs}

cat > /opt/standby/traefik/docker-compose.yml << 'COMPOSE'
services:
  traefik:
    image: traefik:v3.2
    container_name: traefik-standby
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedByDefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=jeff@jeffemmett.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/certs/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./certs:/certs
      - ./config:/config
    restart: unless-stopped
    networks:
      - traefik-public

networks:
  traefik-public:
    name: traefik-public
    driver: bridge
COMPOSE

# --- Critical service standby containers ---
echo "[2/3] Creating standby service definitions..."

cat > /opt/standby/docker-compose.yml << 'COMPOSE'
# Warm standby services - start these on failover
# PostgreSQL instances use streaming replicas (see 03-backup-target.sh)

services:
  # rSpace Online - primary product
  rspace:
    image: gitea.jeffemmett.com/jeff/rspace-online:latest
    container_name: rspace-standby
    env_file: .env.rspace
    depends_on:
      - rspace-db
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.rspace.rule=Host(`rspace.online`)"
      - "traefik.http.routers.rspace.tls.certresolver=letsencrypt"
    restart: unless-stopped
    networks:
      - traefik-public
      - standby-internal

  rspace-db:
    image: postgres:16
    container_name: rspace-db-standby
    volumes:
      - rspace-db-data:/var/lib/postgresql/data
    command: postgres -c hot_standby=on
    restart: unless-stopped
    networks:
      - standby-internal

  # EncryptID - authentication
  encryptid:
    image: gitea.jeffemmett.com/jeff/encryptid:latest
    container_name: encryptid-standby
    env_file: .env.encryptid
    depends_on:
      - encryptid-db
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.encryptid.rule=Host(`auth.rspace.online`) || Host(`encryptid.jeffemmett.com`)"
      - "traefik.http.routers.encryptid.tls.certresolver=letsencrypt"
    restart: unless-stopped
    networks:
      - traefik-public
      - standby-internal

  encryptid-db:
    image: postgres:16
    container_name: encryptid-db-standby
    volumes:
      - encryptid-db-data:/var/lib/postgresql/data
    command: postgres -c hot_standby=on
    restart: unless-stopped
    networks:
      - standby-internal

volumes:
  rspace-db-data:
  encryptid-db-data:

networks:
  traefik-public:
    external: true
  standby-internal:
    driver: bridge
COMPOSE

# --- Failover script ---
echo "[3/3] Creating failover activation script..."

cat > /opt/standby/activate-failover.sh << 'SCRIPT'
#!/usr/bin/env bash
# Activate failover: promote replicas and start standby services
set -euo pipefail

echo "=== ACTIVATING FAILOVER ==="
echo "$(date): Failover initiated"

# Step 1: Promote PostgreSQL replicas to primary
echo "[1/4] Promoting PostgreSQL replicas..."
for container in rspace-db-standby encryptid-db-standby rinbox-db-standby; do
  if docker ps -a --format '{{.Names}}' | grep -q "$container"; then
    docker exec "$container" pg_ctl promote -D /var/lib/postgresql/data/pgdata 2>/dev/null || true
    echo "  Promoted: $container"
  fi
done

# Step 2: Start Traefik
echo "[2/4] Starting Traefik..."
cd /opt/standby/traefik && docker compose up -d

# Step 3: Start application services
echo "[3/4] Starting standby services..."
cd /opt/standby && docker compose up -d

# Step 4: Activate Cloudflare Tunnel
echo "[4/4] Activating Cloudflare Tunnel..."
if systemctl is-enabled cloudflared &>/dev/null; then
  systemctl start cloudflared
  echo "  Cloudflare Tunnel activated"
else
  echo "  WARNING: cloudflared not configured. Manual DNS switch needed."
fi

echo ""
echo "=== FAILOVER ACTIVE ==="
echo "$(date): All standby services are running"
echo ""
echo "Services available via Cloudflare Tunnel (if configured)"
echo "Manual DNS switch: Update Cloudflare DNS A records to this server's public IP"

# Send alert
/opt/standby/send-failover-alert.sh
SCRIPT
chmod +x /opt/standby/activate-failover.sh

cat > /opt/standby/deactivate-failover.sh << 'SCRIPT'
#!/usr/bin/env bash
# Deactivate failover: stop standby services, return to replica mode
set -euo pipefail

echo "=== DEACTIVATING FAILOVER ==="
echo "WARNING: This will stop local services. Ensure Netcup is back online first."
read -p "Continue? (yes/no) > " CONFIRM
[ "$CONFIRM" = "yes" ] || exit 1

# Stop application services
cd /opt/standby && docker compose down
cd /opt/standby/traefik && docker compose down

# Stop Cloudflare Tunnel
systemctl stop cloudflared 2>/dev/null || true

echo "Failover deactivated. Re-sync databases from Netcup to restore replica state."
echo "Run: ./03-backup-target.sh --init-replica"
SCRIPT
chmod +x /opt/standby/deactivate-failover.sh

echo ""
echo "=== Warm standby setup complete ==="
echo ""
echo "Standby services are configured but NOT started."
echo "To activate failover: /opt/standby/activate-failover.sh"
echo "To deactivate:        /opt/standby/deactivate-failover.sh"
echo ""
echo "Next: ./06-failover.sh"
