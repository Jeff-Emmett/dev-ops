#!/usr/bin/env bash
# Phase 1: Base installation for backup NAS / failover node
# Run on fresh Ubuntu Server 24.04 LTS
set -euo pipefail

NODE_NAME="${1:-backup-nas}"

echo "=== Backup NAS Base Install ==="
echo "Node name: $NODE_NAME"
echo ""

# --- System updates ---
echo "[1/5] Updating system..."
apt-get update && apt-get upgrade -y
apt-get install -y \
  curl wget git htop tmux \
  net-tools iperf3 \
  mdadm smartmontools \
  nut nut-client \
  restic rclone \
  postgresql-client-16

# --- Docker ---
echo "[2/5] Installing Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
fi

# Install docker compose plugin
apt-get install -y docker-compose-plugin

# --- Tailscale ---
echo "[3/5] Installing Tailscale..."
if ! command -v tailscale &>/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

echo ""
echo ">>> Join the Headscale mesh:"
echo "    tailscale up --login-server https://hs.jeffemmett.com --hostname $NODE_NAME"
echo ""
read -p "Press Enter after joining Tailscale..."

# Verify connectivity
echo "Testing Tailscale connectivity to Netcup..."
if tailscale ping netcup --timeout 10s; then
  echo "  OK: Can reach Netcup via Tailscale"
else
  echo "  WARNING: Cannot reach Netcup. Check Headscale config."
fi

# --- Hostname ---
echo "[4/5] Setting hostname..."
hostnamectl set-hostname "$NODE_NAME"

# --- Firewall ---
echo "[5/5] Configuring firewall..."
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow in on tailscale0  # Allow all traffic on Tailscale interface
ufw --force enable

echo ""
echo "=== Base install complete ==="
echo "Next: ./02-storage-setup.sh"
