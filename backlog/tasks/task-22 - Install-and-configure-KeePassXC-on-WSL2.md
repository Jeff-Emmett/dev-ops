---
id: task-22
title: Install and configure KeePassXC on WSL2
status: To Do
assignee: ''
created_date: '2026-02-13 22:00'
labels: [security, keepass, setup]
priority: high
dependencies: [task-21]
---

## Description

Install KeePassXC on the local development machine (WSL2/Windows) and create the initial vault with the decided-upon security parameters.

## Plan

1. Install KeePassXC
   - Option A: Windows native (runs on Windows side, accesses WSL2 files via \\wsl.localhost\)
   - Option B: WSL2 apt install (requires X11/Wayland forwarding)
   - **Recommendation**: Windows native — better clipboard integration, auto-type works
2. Create vault with Argon2id KDF (parameters from task-21)
3. Generate key file and store securely
4. Set up folder structure inside vault
5. Configure auto-lock (lock after 5 min idle, lock on minimize, lock on screen lock)
6. Enable recycle bin inside vault (soft-delete protection)
7. Set password generator defaults (20+ chars, all character classes)

## Acceptance Criteria

- [ ] KeePassXC installed and launching
- [ ] Vault created with Argon2id KDF at decided parameters
- [ ] Key file generated and stored in secure location
- [ ] Folder structure created per vault design
- [ ] Auto-lock configured
- [ ] Password generator configured
- [ ] Vault file stored in Syncthing-watched directory

## Notes

- KeePassXC on Windows can access WSL2 paths via `\\wsl.localhost\Ubuntu\home\jeffe\KeePass\`
- Alternatively store vault in Windows filesystem and symlink from WSL2
