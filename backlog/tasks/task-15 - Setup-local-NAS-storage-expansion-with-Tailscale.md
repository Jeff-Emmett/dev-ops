---
id: task-15
title: Setup local NAS storage expansion with Tailscale
status: To Do
assignee: [@jeffe]
created_date: '2025-12-20'
labels: [infrastructure, storage, nas, networking]
priority: high
dependencies: []
---

## Description

Expand Netcup storage by connecting a home D-Link DNS-320/325/340 NAS via Tailscale VPN tunnel. This provides additional storage capacity for Jellyfin media without monthly cloud storage costs.

## Problem

- Netcup RS 8000 is at **96% capacity** (2.8TB / 3TB used)
- Only ~125GB remaining for new media
- Need cost-effective storage expansion

## Solution Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        HOME NETWORK                         │
│  ┌──────────────┐      ┌─────────────────┐                 │
│  │ D-Link NAS   │ SMB  │ Raspberry Pi 5  │                 │
│  │ DNS-320/325  │─────→│ (Tailscale      │                 │
│  │ (HDD storage)│      │  Subnet Router) │                 │
│  └──────────────┘      └────────┬────────┘                 │
│                                 │                           │
│                         Tailscale VPN                       │
└─────────────────────────────────┼───────────────────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │      Netcup RS 8000       │
                    │      (Tailscale client)   │
                    │                           │
                    │  mount -t cifs            │
                    │  //100.x.x.x/media        │
                    │  /mnt/home-nas            │
                    │                           │
                    │  Jellyfin reads from:     │
                    │  - /opt/media-server/media│
                    │  - /mnt/home-nas/media    │
                    └───────────────────────────┘
```

## Hardware Shopping List

### Raspberry Pi (Tailscale Subnet Router)

| Model | RAM | Price | Notes |
|-------|-----|-------|-------|
| **Raspberry Pi 5 2GB** | 2GB | **$55** | Sufficient for routing |
| Raspberry Pi 5 4GB | 4GB | $65 | Recommended |
| Raspberry Pi 5 8GB | 8GB | $85 | Overkill for this use |
| Raspberry Pi 4 2GB | 2GB | $45 | Budget option |

**Additional Pi accessories needed:**
- Power supply (USB-C 27W): ~$12
- MicroSD card (32GB+): ~$10
- Case (optional): ~$10
- **Total Pi setup: ~$75-100**

### NAS Hard Drives

Current best prices (December 2025):

| Capacity | Drive Model | Price | $/TB | Notes |
|----------|-------------|-------|------|-------|
| **8TB** | Seagate IronWolf | **$160** | $20/TB | Good value |
| **8TB** | WD Red Plus | $170 | $21/TB | CMR, reliable |
| **12TB** | Seagate IronWolf | **$220** | $18/TB | Best $/TB |
| **12TB** | Toshiba N300 | $200 | $17/TB | Budget pick |
| **16TB** | Toshiba N300 | $280 | $17.50/TB | Lowest $/GB |
| 16TB | Seagate IronWolf Pro | $350 | $22/TB | Enterprise |

**Recommendations:**
- **Best value**: 2x 12TB Toshiba N300 = **$400** (24TB total)
- **Budget**: 2x 8TB Seagate IronWolf = **$320** (16TB total)
- **Max capacity**: 2x 16TB Toshiba N300 = **$560** (32TB total)

### D-Link DNS-320/325 Compatibility

The DNS-320 supports:
- 2x 3.5" SATA drives (up to 16TB each confirmed)
- RAID 0, 1, JBOD, Standard modes
- SMB/CIFS file sharing
- Max theoretical: 32TB (2x 16TB)

## Total Cost Estimates

| Setup | Storage | One-time Cost | Monthly Cost |
|-------|---------|---------------|--------------|
| **Budget** | 16TB | $395 | $0 |
| **Recommended** | 24TB | $475 | $0 |
| **Maximum** | 32TB | $635 | $0 |

**vs Cloud alternatives (monthly):**
- Hetzner Storage Box 24TB: ~$55/month = $660/year
- Cloudflare R2 24TB: $360/month = $4,320/year
- Backblaze B2 24TB: $144/month = $1,728/year

**Break-even: ~8-9 months** vs Hetzner, then pure savings!

## Implementation Plan

### Phase 1: Hardware Acquisition
- [ ] Purchase Raspberry Pi 5 (2GB or 4GB)
- [ ] Purchase Pi power supply + microSD
- [ ] Purchase 2x NAS HDDs (12TB or 16TB recommended)
- [ ] Test HDDs with D-Link NAS

### Phase 2: NAS Setup
- [ ] Install new HDDs in D-Link NAS
- [ ] Configure RAID 1 (mirror) or JBOD (max space)
- [ ] Create SMB share: `//nas-ip/media`
- [ ] Test local network access

### Phase 3: Raspberry Pi Setup
- [ ] Flash Raspberry Pi OS Lite to microSD
- [ ] Install Tailscale: `curl -fsSL https://tailscale.com/install.sh | sh`
- [ ] Enable subnet routing:
  ```bash
  sudo tailscale up --advertise-routes=192.168.1.0/24 --accept-dns=false
  ```
- [ ] Approve subnet routes in Tailscale admin console

### Phase 4: Netcup Integration
- [ ] Install Tailscale on Netcup (if not already)
- [ ] Accept subnet routes on Netcup
- [ ] Create mount point: `mkdir -p /mnt/home-nas`
- [ ] Add to `/etc/fstab`:
  ```
  //100.x.x.x/media /mnt/home-nas cifs credentials=/root/.nas-creds,uid=1000,gid=1000,iocharset=utf8 0 0
  ```
- [ ] Test mount: `mount /mnt/home-nas`

### Phase 5: Jellyfin Configuration
- [ ] Add new library path in Jellyfin: `/mnt/home-nas/movies`
- [ ] Configure for "archive" content (less-watched media)
- [ ] Test streaming performance

## Expected Performance

| Content Type | Expected Performance |
|--------------|---------------------|
| 1080p video | Smooth streaming |
| 4K video | May buffer on seeks |
| Music | No issues |
| Old/archive content | Perfect use case |

**Note:** Home upload speed is 30-100 Mbps. Keep frequently-watched content on local Netcup NVMe, use NAS for archive/overflow.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Home internet outage | Content on NAS unavailable; keep essentials on Netcup |
| NAS hardware failure | Use RAID 1 for redundancy |
| Slow seeks on 4K | Transcode to 1080p or keep 4K on Netcup |
| Pi failure | Simple to replace; Tailscale config in cloud |

## References

- [Tailscale Subnet Routers](https://tailscale.com/kb/1019/subnets)
- [Raspberry Pi 5 Pricing](https://www.raspberrypi.com/products/raspberry-pi-5/)
- [NAS Drive Comparison](https://nascompares.com/cheapest-hard-drives-hdd/)
- [Disk Prices Tracker](https://diskprices.com/)

## Notes

- Consider future upgrade to Synology/QNAP NAS with native Tailscale support
- Monitor home upload bandwidth during streaming
- Set up monitoring/alerts for NAS availability
