---
id: TASK-HIGH.3
title: 'Complete Logseq setup — sync across PC, mobile & web'
status: To Do
assignee: []
created_date: '2026-03-16 05:18'
labels: []
dependencies: []
parent_task_id: TASK-HIGH
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Finish setting up Logseq graph (migrated from Obsidian) with full cross-device sync. Graph is at ~/Github/logseq-graph/ with Git remote on Gitea.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Desktop: Clone logseq-graph on Windows and open in Logseq desktop app
- [ ] #2 Desktop: Verify git auto-commit/push working (git-auto-push: true in config.edn)
- [ ] #3 Desktop: Configure SSH key if needed (git config core.sshCommand)
- [ ] #4 Mobile: Add logseq-graph as Syncthing Send & Receive folder with Staggered versioning
- [ ] #5 Mobile: Accept Syncthing share on Android, set path to /storage/emulated/0/logseq-graph/
- [ ] #6 Mobile: Open Logseq mobile and add graph from Syncthing folder
- [ ] #7 Web/API: Enable Logseq HTTP API server (Settings → Features → port 12315)
- [ ] #8 Web/API: Install mcp-server-logseq by ergut for Claude Code integration
- [ ] #9 Plugins: Install logseq-journals-calendar, logseq-tabs, logseq-todo-list, logseq-plugin-git
- [ ] #10 Security: Rotate API keys found in imported notes (Anthropic key.md, Cloudflare API Calls.md)
- [ ] #11 Cleanup: Disable obsidian-git plugin in Windows Obsidian vault
- [ ] #12 Cleanup: Archive or remove stale Obsidian clone at ~/Github/Jeff's Vault/
- [ ] #13 Verify: Confirm bidirectional sync flow — Desktop↔Gitea and Desktop↔Mobile via Syncthing
<!-- AC:END -->
