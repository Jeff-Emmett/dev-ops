---
id: task-21
title: Research KeePass security best practices and vault design
status: To Do
assignee: ''
created_date: '2026-02-13 22:00'
labels: [security, keepass, research]
priority: high
dependencies: []
---

## Description

Research and document KeePass security best practices before implementation. Decide on vault structure (single vs multiple), KDF parameters, key file strategy, and threat model.

## Plan

1. Determine KDF settings (Argon2id iterations, memory, parallelism)
   - Default KeePassXC: 1s transform time — increase for high-security vaults
   - Recommended: Argon2id, 64MB memory, 4 iterations minimum
2. Decide single vault vs multiple vaults
   - Single: simpler sync, one master password to remember
   - Multiple: compartmentalization (compromise of one doesn't expose all)
   - **Recommendation**: Single vault with strong folder hierarchy + key file
3. Key file strategy
   - Generate a random key file (not derived from password)
   - Store key file SEPARATELY from vault (not in same Syncthing folder)
   - Key file on USB + local copy, NOT synced automatically
   - This provides true 2FA: something you know (password) + something you have (key file)
4. Backup key file securely (print as QR code? USB in safe?)
5. Document emergency access procedure

## Acceptance Criteria

- [ ] KDF parameters chosen and documented
- [ ] Vault structure decided (single vs multi)
- [ ] Key file generation and storage plan documented
- [ ] Emergency access / recovery procedure documented
- [ ] Threat model written (what are we protecting against?)

## Notes

