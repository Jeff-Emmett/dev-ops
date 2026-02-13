---
id: TASK-23
title: Configure Syncthing folder for KeePass vault sync
status: Done
assignee: []
created_date: '2026-02-13 22:00'
updated_date: '2026-02-13 20:58'
labels:
  - security
  - keepass
  - syncthing
  - sync
dependencies:
  - task-22
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up a dedicated Syncthing shared folder for KeePass vault sync between laptop, Netcup (backup), and Android phone.

## Plan

1. Create dedicated sync folder (e.g., `~/KeePass/` on laptop, `/root/KeePass/` on Netcup)
2. Add folder to Syncthing on laptop (local API: `localhost:8384`)
3. Add folder to Syncthing on Netcup (API key in CLAUDE.md)
4. Share folder between laptop and Netcup devices
5. Configure folder settings:
   - **File versioning**: Staggered (keeps old versions: 30 versions for 30 days, then weekly for 6 months)
   - **Ignore patterns**: `*.lock`, `*.tmp`, `*~` (KeePassXC lock files)
   - **Folder type**: Send & Receive on all devices
   - **Sync conflict handling**: KeePassXC handles .kdbx merge conflicts natively
6. Add Android device to Syncthing later (task-25)

## Security Considerations

- Syncthing uses TLS 1.3 for transport encryption
- Vault is AES-256 encrypted at rest — even if Syncthing is compromised, vault is safe
- Key file should NOT be in this sync folder (separate distribution)
- Netcup copy serves as encrypted backup (they can't read it without master password + key file)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Syncthing folder created on laptop
- [ ] #2 Syncthing folder created on Netcup
- [ ] #3 Devices connected and folder shared
- [ ] #4 File versioning configured (staggered)
- [ ] #5 Ignore patterns set for lock files
- [ ] #6 Test: modify vault on laptop, verify sync to Netcup
- [ ] #7 Test: verify vault integrity after sync
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Syncthing folder 'keepass' configured: ~/KeePass ↔ Netcup /root/Sync/KeePass, staggered versioning, .stignore for lock files
<!-- SECTION:NOTES:END -->

## Notes

- Syncthing is already running on both devices (see CLAUDE.md Syncthing section)
- Netcup Syncthing API key: `9qMXtcah4bvTE6ntLdEVoGxJNVHsXzhP`
- Local Syncthing API key: `PNN2WiDGpk29XPSCmP7FA9ty4brcH4F9`
