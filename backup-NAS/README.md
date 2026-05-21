# Backup NAS + Failover Server

Multi-location redundancy system for all operational services on Netcup RS 8000.

## What This Is

A local mini-server + NAS array that provides:
1. **NAS** - Large media storage, replaces Hetzner Storage Box
2. **Warm standby** - Docker containers ready to promote when Netcup is down
3. **Local Jellyfin** - Direct LAN playback, no transcoding/buffering
4. **Backup target** - Third copy for 3-2-1 strategy (Netcup + R2 + local)
5. **Future: dAppNode/ETH staking** (TASK-60)

## Quick Start

```bash
# After hardware assembly, run from this directory:
./setup/01-base-install.sh      # OS, Docker, Tailscale
./setup/02-storage-setup.sh     # RAID config, mount points
./setup/03-backup-target.sh     # Restic repo, PostgreSQL replication
./setup/04-media-server.sh      # Jellyfin + arr stack
./setup/05-warm-standby.sh      # Critical service containers
./setup/06-failover.sh          # Cloudflare Tunnel + health checks
```

## Multi-Location Deployment

This setup is designed to run at **any location** connected via Tailscale/Headscale:
- Home office (primary)
- Friend/family location (offsite)
- Coworking space
- Any location with stable internet + power

Each node joins the Headscale mesh and appears as a failover target.

## Files

| File | Purpose |
|------|---------|
| `BOM.html` | Bill of Materials with purchase links and images |
| `architecture.md` | Network architecture and failover design |
| `setup/` | Step-by-step setup scripts |
| `docker-compose.yml` | Warm standby service definitions |
| `cloudflare-failover.yml` | Cloudflare health check + failover config |

## Cost Summary

| | Monthly | Annual |
|---|---------|--------|
| **Current** (Netcup + Hetzner + R2) | ~$163 | $1,956 |
| **After** (Netcup + R2 + electricity) | ~$128 | $1,536 |
| **Hardware (one-time)** | — | ~$1,100-1,500 |
| **Breakeven** | — | ~30-36 months |

## Related Tasks

- TASK-15: NAS storage expansion (superseded by this)
- TASK-28: KeePass 3-2-1 backup (Phase 3)
- TASK-60: HoloPort/dAppNode (can share this hardware)
