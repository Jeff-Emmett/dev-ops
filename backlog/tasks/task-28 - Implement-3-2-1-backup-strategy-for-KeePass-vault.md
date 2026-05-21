---
id: TASK-28
title: Implement 3-2-1 backup strategy for KeePass vault
status: Done
assignee: []
created_date: '2026-02-13 22:00'
updated_date: '2026-05-09 06:11'
labels:
  - security
  - keepass
  - backup
dependencies:
  - task-23
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement a robust 3-2-1 backup strategy for the KeePass vault and key file, ensuring no single point of failure can cause total credential loss.

## 3-2-1 Rule
- **3** copies of data
- **2** different storage media/types
- **1** offsite copy

## Plan

### Vault Backup (3 copies minimum)
1. **Copy 1 — Local laptop** (primary, via Syncthing)
   - `~/KeePass/vault.kdbx`
   - Syncthing staggered versioning keeps 30 days of old versions
2. **Copy 2 — Netcup server** (offsite, via Syncthing)
   - `/root/KeePass/vault.kdbx`
   - Also covered by Syncthing versioning
3. **Copy 3 — Encrypted offsite backup** (Restic → Cloudflare R2)
   - Add KeePass directory to existing Restic backup job
   - Encrypted at rest (Restic encryption + vault's own AES-256)
   - R2 provides geographic redundancy (Cloudflare edge)
4. **Copy 4 (bonus) — Android phone** (via Syncthing)
   - Additional copy on mobile device

### Key File Backup (CRITICAL — separate from vault)
1. **Copy 1 — Local laptop** (not in Syncthing folder)
   - `~/.keepass-keyfile` (chmod 400)
2. **Copy 2 — USB flash drive** (in physically secure location)
   - Encrypted USB or key file in encrypted container
3. **Copy 3 — Printed QR code** (in safe/lockbox)
   - `qrencode -o keyfile-qr.png < ~/.keepass-keyfile`
   - Physical backup survives digital disasters
4. **Copy 4 — Netcup** (optional, in /root/.keepass-keyfile, chmod 400)
   - Only if comfortable with server having both vault + key

### Emergency Recovery Procedure
- Document step-by-step recovery from each backup source
- Test recovery annually
- Store recovery instructions with physical key file backup

### Automated Verification
- Cron job to verify vault integrity: `keepassxc-cli ls vault.kdbx` (weekly)
- Syncthing monitoring: alert if sync fails for > 24 hours
- Restic backup verification: `restic check` (monthly)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Vault syncing to at least 3 locations
- [ ] #2 Key file stored in at least 2 separate secure locations
- [x] #3 Restic backup includes KeePass directory
- [ ] #4 Vault integrity check cron job set up
- [ ] #5 Emergency recovery procedure documented and tested
- [ ] #6 QR code of key file printed and stored securely
- [ ] #7 Recovery test performed successfully from backup
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## 2026-05-09 — Closure with TASK-66 supersession

Per established memory entry ("TASK-66 supersedes TASK-15, TASK-28, TASK-MEDIUM.9"), this task is being closed in favor of TASK-66 (Local AI Server + NAS) which absorbs the full 3-2-1 backup story including KeePass.

**What landed today:**
- AC #3 fixed: KeePass directories added to restic CONFIG_DIRS in `/opt/backup-system/backup-docker.sh`. Tomorrow's 03:00 restic snapshot will include `/root/KeePass/`, `/root/Sync/KeePass/`, `/root/.config/keepassxc/`. Pre-change backup at `/opt/backup-system/backup-docker.sh.bak.pre-keepass-2026-05-09`.
- Discovered: infra-wide 3-2-1 backup is already operational (restic→R2 + Hetzner Storage Box sync, daily). KeePass now rides that pipeline.

**Still pending under TASK-66:**
- AC #1, #2, #6 — physical/key-file separation procedures
- AC #4 — vault integrity check cron
- AC #5 — emergency recovery doc
- AC #7 — recovery test

These belong to the local-NAS hardware build (TASK-66, BOM ready) where the KeePass key file gets a separate physical home + the recovery test cycle is set up.

<!-- AC_WAIVED -->
<!-- SECTION:NOTES:END -->

## Notes

- The vault itself is encrypted — even unencrypted backups of the .kdbx are safe
- Key file is the critical piece — lose it + forget password = permanent lockout
- Consider also storing master password hint in physical safe (NOT the password itself)
