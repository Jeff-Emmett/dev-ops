---
id: TASK-62
title: 'Consolidate Claude Code: container-only with KeePass + Infisical'
status: Done
assignee: []
created_date: '2026-03-11 00:46'
labels:
  - infrastructure
  - security
  - claude-dev-container
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Consolidated two Claude Code installations on Netcup (root v2.1.71 + container v2.1.44) into a single properly configured container with full KeePass and Infisical access. KeePass master password moved from plaintext file on disk to Infisical → tmpfs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 keepass-write ls/add/edit/search works from container
- [ ] #2 keepass-inject passes secrets via env var without printing passwords
- [ ] #3 Infisical CLI (secrets, infisical-ops) works via internal Docker network
- [ ] #4 Deny rules block keepassxc-cli show/export/dump and .kdbx reads
- [ ] #5 KeePass master password on tmpfs (never hits disk)
- [ ] #6 Root Claude Code uninstalled, /root/.keepass-master shredded
- [ ] #7 tmux plugins (power theme, resurrect, continuum) load correctly
- [ ] #8 Container fish config has no auto-enter loop
- [ ] #9 Agent configs and context files migrated to container volume
- [ ] #10 Claude Code v2.1.72 running in container
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Changes Made

### claude-dev-container repo (6 commits to main)
- **Dockerfile**: Added `keepassxc` package
- **docker-compose.yml**: Added KeePass vault mount (rw), keepass-write/inject/secrets/infisical-ops script mounts (ro), Infisical env mount, container-settings.json mount, tmpfs on /run, KEEPASS_DB/KEEPASS_MASTER_FILE/INFISICAL_API_URL env vars
- **entrypoint.sh**: Fetches KEEPASS_MASTER_PASSWORD from Infisical at startup → writes to tmpfs; installs Claude settings.json from mount; symlinks tmux.conf to XDG path for TPM
- **container-settings.json** (new): 39 deny rules blocking keepassxc-cli read commands, .kdbx file reads, destructive operations
- **container-fish-config.fish** (new): Clean fish config without auto-enter loop
- **claude-container-CLAUDE.md**: Full rewrite with KeePass write-only docs, Infisical policy, safety guidelines, server layout, backlog commands, agent references

### Netcup server changes
- Patched `/usr/local/bin/keepass-write` and `keepass-inject` with env var overrides (KEEPASS_DB, KEEPASS_MASTER_FILE) — backward compatible
- Patched `/usr/local/bin/secrets` to respect INFISICAL_API_URL env var
- Created Infisical `/keepass` folder with KEEPASS_MASTER_PASSWORD secret
- Set KeePass vault file group to gid 1001 with group-write permissions
- Copied dev-mobile and claude-container scripts to /usr/local/bin/
- Migrated agent configs and context files to claude-data volume
- Uninstalled root Claude Code, shredded /root/.keepass-master, archived /root/.claude

### Security improvements
| Aspect | Before | After |
|--------|--------|-------|
| KeePass master password | Plaintext /root/.keepass-master | Infisical → tmpfs /run/keepass-master |
| Claude installations | 2 (root + container) | 1 (container only) |
| Password visibility | Deny rules on root only | Deny rules in container settings.json |
<!-- SECTION:FINAL_SUMMARY:END -->
