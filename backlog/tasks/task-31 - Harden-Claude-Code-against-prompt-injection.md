---
id: TASK-31
title: Harden Claude Code against prompt injection
status: Done
assignee: []
created_date: '2026-02-17 21:06'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Added fish wrapper (claude.fish) and deny rules (settings.json) to protect against prompt injection from external documents, web content, and malicious CLAUDE.md files in third-party repos. This task tracks the completed work and any follow-up hardening.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Completed 2026-02-17:
- Fish wrapper at ~/.config/fish/functions/claude.fish
  - Warns on CLAUDE.md/.claude/settings.json in untrusted repos
  - Auto-trusts repos with gitea.jeffemmett.com/jeffemmett/ remote
  - Shows first 10 lines preview, requires y/N confirmation
- Deny rules in ~/.claude/settings.json (23 patterns):
  - Destructive filesystem (rm -rf /, mkfs, dd)
  - Git destruction (force push main/master, reset --hard origin)
  - Secret exfiltration (pipe ~/.secrets to curl/wget)
  - Remote code execution (curl|sh, wget|bash)
  - Database destruction (DROP TABLE/DATABASE, TRUNCATE)
  - System destruction (shutdown, chmod 777)
- Limitation: glob-based deny rules can be bypassed with encoding tricks
  - Primary defense remains user approval on every Bash/Write/Edit call
<!-- SECTION:NOTES:END -->
