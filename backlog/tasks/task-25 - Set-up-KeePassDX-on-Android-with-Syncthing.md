---
id: task-25
title: Set up KeePassDX on Android with Syncthing
status: To Do
assignee: ''
created_date: '2026-02-13 22:00'
labels: [security, keepass, android, sync]
priority: medium
dependencies: [task-23]
---

## Description

Install KeePassDX on Android phone, connect it to the Syncthing-synced vault, and configure biometric unlock for daily use.

## Plan

1. Install **Syncthing** on Android (F-Droid or Play Store)
   - Add laptop + Netcup as devices
   - Share the KeePass sync folder
   - Verify vault file syncs to phone
2. Install **KeePassDX** on Android (F-Droid recommended for open-source build)
3. Open vault from Syncthing folder
4. Transfer key file to phone via:
   - USB cable (most secure)
   - QR code scan
   - NOT via Syncthing (key file must be separate from vault)
5. Configure KeePassDX:
   - Enable biometric unlock (fingerprint)
   - Set auto-lock timeout (2 min)
   - Enable autofill service (Android Settings → Autofill → KeePassDX)
   - Disable clipboard timeout or set to 30s
6. Test autofill in browser and apps

## Acceptance Criteria

- [ ] Syncthing running on Android and syncing vault
- [ ] KeePassDX installed and can open vault
- [ ] Key file transferred securely to phone
- [ ] Biometric unlock configured
- [ ] Autofill service enabled and working
- [ ] Test: log into 3+ apps/sites using KeePassDX autofill

## Notes

- KeePassDX handles .kdbx merge conflicts if vault is edited on two devices simultaneously
- Syncthing on Android can run in background with battery optimization exceptions
