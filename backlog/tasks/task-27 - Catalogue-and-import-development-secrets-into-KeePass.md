---
id: task-27
title: Catalogue and import development secrets into KeePass
status: To Do
assignee: ''
created_date: '2026-02-13 22:00'
labels: [security, keepass, secrets, migration]
priority: medium
dependencies: [task-22]
---

## Description

Audit all development platform secrets currently stored in `~/.secrets/`, CLAUDE.md, Netcup `/opt/secrets/`, and various `.env` files. Import them into the KeePass vault under the Development/Infrastructure folders.

## Plan

1. **Audit local secrets** (`~/.secrets/`)
   - List all files: `ls ~/.secrets/`
   - Document each secret's purpose and service
2. **Audit CLAUDE.md credentials**
   - Extract all API keys, tokens, credentials mentioned
   - Note which are still in plaintext in CLAUDE.md (should be references to ~/.secrets/)
3. **Audit Netcup secrets** (`/opt/secrets/` and various `.env` files)
   - SSH to Netcup and catalogue all credential files
   - Document which services use which credentials
4. **Create entries in KeePass vault**
   - `Development/API Keys/` — Cloudflare, Porkbun, Resend, RunPod, HuggingFace
   - `Development/Tokens/` — GitHub PAT, Gitea tokens
   - `Infrastructure/Servers/` — Netcup SSH, RunPod SSH
   - `Infrastructure/Databases/` — ERPNext MariaDB, PostgreSQL instances
   - `Infrastructure/Services/` — Syncthing API keys, Traefik, Cloudflare tunnel
   - `Infrastructure/Docker/` — Registry credentials, webhook secrets
5. **Add metadata to each entry**
   - URL of the service
   - Notes on rotation schedule
   - Expiry dates (if applicable)
   - Which .env file / server the secret is deployed to
6. **Do NOT remove existing ~/.secrets/ yet**
   - KeePass is the new source of truth for HUMANS
   - ~/.secrets/ remains for SCRIPTS and automation
   - Document the relationship between the two

## Acceptance Criteria

- [ ] All ~/.secrets/ entries catalogued
- [ ] All CLAUDE.md credentials identified
- [ ] All Netcup /opt/secrets/ entries catalogued
- [ ] All secrets imported into KeePass with proper folder structure
- [ ] Each entry has: service URL, username, notes on where it's deployed
- [ ] Rotation schedule noted for critical secrets
- [ ] Relationship between KeePass and ~/.secrets/ documented

## Notes

- This does NOT replace the ~/.secrets/ directory — scripts still read from there
- KeePass becomes the human-readable, searchable credential database
- Consider adding TOTP (2FA) codes to KeePass entries where applicable
