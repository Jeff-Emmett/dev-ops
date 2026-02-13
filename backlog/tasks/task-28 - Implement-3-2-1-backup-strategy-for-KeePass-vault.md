---
id: task-28
title: Implement 3-2-1 backup strategy for KeePass vault
status: To Do
assignee: ''
created_date: '2026-02-13 22:00'
labels: [security, keepass, backup]
priority: high
dependencies: [task-23]
---

## Description

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

## Acceptance Criteria

- [ ] Vault syncing to at least 3 locations
- [ ] Key file stored in at least 2 separate secure locations
- [ ] Restic backup includes KeePass directory
- [ ] Vault integrity check cron job set up
- [ ] Emergency recovery procedure documented and tested
- [ ] QR code of key file printed and stored securely
- [ ] Recovery test performed successfully from backup

## Notes

- The vault itself is encrypted — even unencrypted backups of the .kdbx are safe
- Key file is the critical piece — lose it + forget password = permanent lockout
- Consider also storing master password hint in physical safe (NOT the password itself)
