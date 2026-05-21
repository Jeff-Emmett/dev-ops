#!/usr/bin/env bash
# Phase 3: Configure as backup target (Restic repo + PostgreSQL replication)
set -euo pipefail

echo "=== Backup Target Setup ==="

# --- Local Restic repo ---
echo "[1/3] Initializing local Restic repository..."
if [ ! -f /mnt/nas/backups/restic-repo/config ]; then
  echo "Enter a password for the local Restic repository:"
  read -sp "> " RESTIC_PASS
  echo ""
  export RESTIC_PASSWORD="$RESTIC_PASS"
  restic init --repo /mnt/nas/backups/restic-repo

  # Save password securely
  echo "RESTIC_PASSWORD=$RESTIC_PASS" > /root/.local-restic-credentials
  chmod 600 /root/.local-restic-credentials
  echo "  Credentials saved to /root/.local-restic-credentials"
else
  echo "  Restic repo already exists, skipping."
fi

# --- Cron: Pull DB dumps from Netcup ---
echo "[2/3] Setting up database dump sync..."
cat > /etc/cron.d/sync-db-dumps << 'CRON'
# Sync database dumps from Netcup every 6 hours
0 */6 * * * root rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no" netcup:/tmp/db-dumps/ /mnt/nas/backups/db-dumps/ >> /var/log/db-dump-sync.log 2>&1
CRON

# --- Cron: Local Restic backup of NAS data ---
cat > /etc/cron.d/local-restic-backup << 'CRON'
# Backup NAS data to local Restic repo (4AM daily)
0 4 * * * root /opt/backup-nas/local-backup.sh >> /var/log/local-backup.log 2>&1
CRON

mkdir -p /opt/backup-nas
cat > /opt/backup-nas/local-backup.sh << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
source /root/.local-restic-credentials
export RESTIC_REPOSITORY=/mnt/nas/backups/restic-repo

echo "$(date): Starting local Restic backup..."

# Backup database dumps and KeePass vault
restic backup \
  /mnt/nas/backups/db-dumps \
  /mnt/nas/backups/keepass \
  --tag local-backup

# Retention: 7 daily, 4 weekly, 3 monthly
restic forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 3 \
  --prune

echo "$(date): Backup complete."
SCRIPT
chmod +x /opt/backup-nas/local-backup.sh

# --- PostgreSQL replication setup ---
echo "[3/3] PostgreSQL streaming replication..."
echo ""
echo "This will configure this node as a PostgreSQL streaming replica."
echo "You'll need to run the primary-side setup on Netcup first."
echo ""
echo "On Netcup, for each database (rspace, encryptid, rinbox):"
echo "  1. Add replication user:"
echo "     CREATE ROLE replica WITH REPLICATION LOGIN PASSWORD 'your_password';"
echo "  2. Update pg_hba.conf:"
echo "     host replication replica <tailscale-ip>/32 md5"
echo "  3. Reload PostgreSQL:"
echo "     docker exec <container> pg_ctl reload"
echo ""
echo "Then run this script again with --init-replica to perform the base backup."
echo ""

if [ "${1:-}" = "--init-replica" ]; then
  echo "Initializing PostgreSQL replicas..."
  # This creates a docker-compose for replica PostgreSQL instances
  cat > /opt/backup-nas/docker-compose.replicas.yml << 'COMPOSE'
services:
  rspace-replica:
    image: postgres:16
    container_name: rspace-db-replica
    environment:
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - rspace-replica-data:/var/lib/postgresql/data
    command: >
      postgres
        -c wal_level=replica
        -c hot_standby=on
    restart: unless-stopped
    networks:
      - replica-net

  encryptid-replica:
    image: postgres:16
    container_name: encryptid-db-replica
    environment:
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - encryptid-replica-data:/var/lib/postgresql/data
    restart: unless-stopped
    networks:
      - replica-net

  rinbox-replica:
    image: postgres:16
    container_name: rinbox-db-replica
    environment:
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - rinbox-replica-data:/var/lib/postgresql/data
    restart: unless-stopped
    networks:
      - replica-net

volumes:
  rspace-replica-data:
  encryptid-replica-data:
  rinbox-replica-data:

networks:
  replica-net:
    driver: bridge
COMPOSE

  echo "Created /opt/backup-nas/docker-compose.replicas.yml"
  echo ""
  echo "To initialize each replica, run:"
  echo "  pg_basebackup -h <netcup-tailscale-ip> -U replica -D <data-dir> -Fp -Xs -P"
  echo ""
fi

echo ""
echo "=== Backup target setup complete ==="
echo "Next: ./04-media-server.sh"
