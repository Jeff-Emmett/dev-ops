#!/usr/bin/env bash
set -euo pipefail

# First-boot setup for Strix Halo Mini PC (Minisforum MS-S1 Max)
# Installs Docker, Tailscale, starts Ollama, pulls models
#
# Usage: curl setup from repo, or:
#   chmod +x setup.sh && sudo ./setup.sh

HEADSCALE_URL="https://vpn.jeffemmett.com"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Strix Halo Mini PC Setup ==="
echo ""

# --- Check root ---
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run as root (sudo ./setup.sh)"
  exit 1
fi

# --- 1. Install Docker ---
if command -v docker &>/dev/null; then
  echo "[OK] Docker already installed: $(docker --version)"
else
  echo "[*] Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
  # Add the invoking user to docker group
  if [[ -n "${SUDO_USER:-}" ]]; then
    usermod -aG docker "$SUDO_USER"
    echo "[OK] Added $SUDO_USER to docker group (re-login to take effect)"
  fi
fi

# Docker Compose (v2 plugin ships with docker now)
if docker compose version &>/dev/null; then
  echo "[OK] Docker Compose available: $(docker compose version --short)"
else
  echo "ERROR: Docker Compose plugin not found. Install manually."
  exit 1
fi

# --- 2. Install AMD ROCm drivers ---
echo ""
echo "[*] Checking ROCm / AMD GPU support..."
if [[ -e /dev/kfd ]]; then
  echo "[OK] /dev/kfd exists — ROCm kernel driver loaded"
else
  echo "[!] /dev/kfd not found. Install AMD ROCm drivers:"
  echo "    https://rocm.docs.amd.com/projects/install-on-linux/en/latest/"
  echo "    After install, reboot and re-run this script."
  echo ""
  echo "    Quick install (Ubuntu 22.04/24.04):"
  echo "      sudo apt install -y amdgpu-dkms rocm-hip-runtime"
  echo "      sudo reboot"
  echo ""
  read -rp "Continue without ROCm? (y/N) " ans
  [[ "$ans" =~ ^[Yy]$ ]] || exit 1
fi

# --- 3. Install Tailscale ---
if command -v tailscale &>/dev/null; then
  echo "[OK] Tailscale already installed: $(tailscale version | head -1)"
else
  echo "[*] Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# Join Headscale mesh
TS_STATUS=$(tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
if [[ "$TS_STATUS" == "Running" ]]; then
  echo "[OK] Tailscale already connected"
else
  echo "[*] Joining Headscale mesh at $HEADSCALE_URL"
  echo ""
  echo "    Run this command to authenticate:"
  echo "      tailscale up --login-server=$HEADSCALE_URL"
  echo ""
  echo "    Then approve the device in Headscale admin:"
  echo "      https://vpn-admin.jeffemmett.com"
  echo ""
  tailscale up --login-server="$HEADSCALE_URL" || true
fi

# --- 4. Start Ollama ---
echo ""
echo "[*] Starting Ollama container..."
cd "$SCRIPT_DIR"
docker compose up -d

echo "[*] Waiting for Ollama to be ready..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:11434/api/tags &>/dev/null; then
    echo "[OK] Ollama is ready"
    break
  fi
  if [[ $i -eq 30 ]]; then
    echo "ERROR: Ollama failed to start within 60s. Check: docker logs ollama-strix"
    exit 1
  fi
  sleep 2
done

# --- 5. Pull models ---
echo ""
echo "[*] Pulling models (this will take a while on first run)..."

MODELS=(
  # Large models — these are the reason for Strix Halo
  "qwen2.5-coder:32b"
  "llama3.1:70b"
  "deepseek-r1:70b"
  "qwen2.5:72b"
  # Small models — same as Netcup Ollama for load-balancing
  "llama3.1:8b"
  "llama3.2:3b"
  "qwen2.5-coder:7b"
  "qwen2.5:7b"
)

for model in "${MODELS[@]}"; do
  echo "  Pulling $model..."
  docker exec ollama-strix ollama pull "$model"
done

echo ""
echo "[OK] All models pulled."
docker exec ollama-strix ollama list

# --- 6. Print summary ---
echo ""
echo "==========================================="
echo "  Strix Halo Setup Complete"
echo "==========================================="

TS_IP=$(tailscale ip -4 2>/dev/null || echo "<not connected>")
echo ""
echo "  Tailscale IP:  $TS_IP"
echo "  Ollama URL:    http://$TS_IP:11434"
echo ""
echo "  Next steps:"
echo "    1. Set STRIX_OLLAMA_URL=http://$TS_IP:11434 in Infisical (litellm project)"
echo "    2. Uncomment Strix Halo entries in litellm/config.yaml on Netcup"
echo "    3. Restart LiteLLM:  cd /opt/apps/litellm && docker compose restart litellm"
echo "    4. Test: curl http://$TS_IP:11434/api/tags"
echo ""
