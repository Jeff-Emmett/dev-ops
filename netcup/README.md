# Netcup RS 8000 Server Configs

Configuration files for the Netcup RS 8000 G12 Pro server.

## Installation

Copy these files to the server and enable the services:

```bash
# Copy systemd services
scp systemd/*.service netcup:/etc/systemd/system/

# Copy cron jobs
scp cron/cleanup-tmp netcup:/etc/cron.d/

# On the server:
ssh netcup
systemctl daemon-reload
systemctl enable --now rclone-hetzner.service
systemctl enable --now media-server-restart.service
```

## Files

### systemd/rclone-hetzner.service
Mounts Hetzner Storage Box at `/mnt/hetzner-media` using rclone SFTP.

Key settings:
- **Cache dir**: `/var/cache/rclone-hetzner` (NOT `/tmp` - prevents filling tmpfs)
- **VFS cache**: 50GB max, full mode for smooth playback
- **Auto-restart**: On failure with 5s delay

### systemd/media-server-restart.service
Automatically restarts media containers when rclone-hetzner restarts.

This prevents stale mount issues where containers lose access to `/mnt/hetzner-media` after rclone restarts.

Containers restarted:
- jellyfin
- qbittorrent
- radarr
- sonarr
- lidarr
- navidrome
- jellyseerr

### cron/cleanup-tmp
Daily cleanup of `/tmp` at 4 AM to prevent disk space issues.

Removes:
- Files not accessed in 24+ hours
- Empty directories

## Troubleshooting

### "Transport endpoint is not connected"
The rclone mount is stale. Restart rclone-hetzner:
```bash
systemctl restart rclone-hetzner
```
The media-server-restart service will automatically restart dependent containers.

### Health checks failing / Traefik 404s
Check if `/tmp` is full:
```bash
df -h /tmp
```
If full, clear it:
```bash
rm -rf /tmp/rclone
systemctl restart rclone-hetzner
```

### Check mount status
```bash
systemctl status rclone-hetzner
ls -la /mnt/hetzner-media/media/movies/
```
