#!/usr/bin/env bash
# Phase 4: Deploy Jellyfin + *arr media stack locally
set -euo pipefail

echo "=== Media Server Setup ==="

# --- Clone jellyfin-media config ---
echo "[1/3] Setting up media server configuration..."
mkdir -p /opt/apps/jellyfin-media/config/{jellyfin,jellyseerr,sonarr,radarr,prowlarr,lidarr,qbittorrent,wizarr}

# --- Docker Compose ---
echo "[2/3] Creating docker-compose..."
cat > /opt/apps/jellyfin-media/docker-compose.yml << 'COMPOSE'
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    environment:
      - JELLYFIN_PublishedServerUrl=http://jellyfin.local
    volumes:
      - ./config/jellyfin:/config
      - /mnt/nas/media:/media
    ports:
      - "8096:8096"
    devices:
      - /dev/dri:/dev/dri  # AMD hardware transcoding
    restart: unless-stopped
    networks:
      - media-network

  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    volumes:
      - ./config/jellyseerr:/app/config
    ports:
      - "5055:5055"
    restart: unless-stopped
    networks:
      - media-network

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Toronto
    volumes:
      - ./config/sonarr:/config
      - /mnt/nas/media/shows:/tv
      - /mnt/nas/media/downloads:/downloads
    ports:
      - "8989:8989"
    restart: unless-stopped
    networks:
      - media-network

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Toronto
    volumes:
      - ./config/radarr:/config
      - /mnt/nas/media/movies:/movies
      - /mnt/nas/media/downloads:/downloads
    ports:
      - "7878:7878"
    restart: unless-stopped
    networks:
      - media-network

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Toronto
    volumes:
      - ./config/prowlarr:/config
    ports:
      - "9696:9696"
    restart: unless-stopped
    networks:
      - media-network

  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    container_name: lidarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Toronto
    volumes:
      - ./config/lidarr:/config
      - /mnt/nas/media/music:/music
      - /mnt/nas/media/downloads:/downloads
    ports:
      - "8686:8686"
    restart: unless-stopped
    networks:
      - media-network

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Toronto
      - WEBUI_PORT=8080
    volumes:
      - ./config/qbittorrent:/config
      - /mnt/nas/media/downloads:/downloads
    ports:
      - "8080:8080"
      - "6881:6881"
      - "6881:6881/udp"
    restart: unless-stopped
    networks:
      - media-network

networks:
  media-network:
    driver: bridge
COMPOSE

# --- Start ---
echo "[3/3] Starting media server..."
cd /opt/apps/jellyfin-media
docker compose up -d

echo ""
echo "=== Media server running ==="
echo ""
echo "Access locally:"
echo "  Jellyfin:    http://$(hostname -I | awk '{print $1}'):8096"
echo "  Jellyseerr:  http://$(hostname -I | awk '{print $1}'):5055"
echo "  Sonarr:      http://$(hostname -I | awk '{print $1}'):8989"
echo "  Radarr:      http://$(hostname -I | awk '{print $1}'):7878"
echo "  Prowlarr:    http://$(hostname -I | awk '{print $1}'):9696"
echo "  Lidarr:      http://$(hostname -I | awk '{print $1}'):8686"
echo "  qBittorrent: http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo "Next: ./05-warm-standby.sh"
