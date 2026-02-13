---
id: task-20
title: Deploy KeePass password manager with cross-device sync
status: To Do
assignee: ''
created_date: '2026-02-13 22:00'
labels: [security, keepass, infrastructure]
priority: high
dependencies: []
---

## Description

Deploy a self-hosted KeePass-compatible password management system with cross-device sync, consolidating all existing passwords (Google Passwords, browser-saved credentials, development platform secrets) into a single encrypted vault with maximum security and backup redundancy.

## Goals

1. **Consolidate all credential sources** into KeePass vaults
2. **Cross-device sync** (WSL2 laptop, Android phone, any browser)
3. **Maximum security** (offline-first, encrypted at rest, no cloud dependency)
4. **Backup redundancy** (local + Netcup + encrypted offsite)
5. **Developer-friendly** (CLI access, integration with existing ~/.secrets/ workflow)

## Architecture Decision

### Recommended Stack
- **KeePassXC** (desktop client) - Linux/Windows, auto-type, browser integration
- **KeePassDX** (Android client) - Material design, biometric unlock
- **Syncthing** (sync engine) - Already deployed! Zero-knowledge, P2P encrypted
- **.kdbx vault format** - Open standard, AES-256 + Argon2id KDF

### Why NOT Vaultwarden/Bitwarden?
- Adds server dependency (single point of failure)
- Database must be online to access passwords
- KeePass is offline-first: vault file works without any server
- Syncthing already handles sync with E2E encryption

### Vault Structure (Proposed)
```
~/KeePass/
├── personal.kdbx          # Google passwords, personal accounts
├── development.kdbx       # API keys, tokens, SSH passphrases
├── infrastructure.kdbx    # Server credentials, DB passwords
└── shared.kdbx            # Shared team credentials (if needed)
```

Or single vault with folder hierarchy:
```
vault.kdbx
├── Personal/
│   ├── Google/
│   ├── Social/
│   ├── Banking/
│   └── Shopping/
├── Development/
│   ├── API Keys/
│   ├── Tokens/
│   └── SSH/
├── Infrastructure/
│   ├── Netcup/
│   ├── Cloudflare/
│   ├── RunPod/
│   └── Databases/
└── Services/
    ├── Gitea/
    ├── ERPNext/
    └── Other Self-Hosted/
```

## Acceptance Criteria

- [ ] KeePassXC installed and configured on WSL2
- [ ] KeePassDX installed on Android
- [ ] Syncthing folder configured for .kdbx sync
- [ ] Google Passwords exported and imported
- [ ] Browser-saved passwords exported and imported
- [ ] Development secrets (from ~/.secrets/) catalogued
- [ ] Infrastructure credentials documented in vault
- [ ] Backup strategy implemented (3-2-1 rule)
- [ ] Browser integration (KeePassXC-Browser) working
- [ ] Key file + master password configured (dual-factor)

## Notes

- This is the parent/epic task. See subtasks (task-21 through task-28) for implementation steps.
- Syncthing is already deployed on both laptop and Netcup (see CLAUDE.md Syncthing section).
