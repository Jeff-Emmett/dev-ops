---
id: TASK-56
title: 'Claude Code pipeline: hooks, commands, model routing, and memory restructuring'
status: Done
assignee:
  - '@claude'
created_date: '2026-02-26 02:26'
labels:
  - infrastructure
  - claude-code
  - optimization
dependencies: []
references:
  - 'https://github.com/anthropics/knowledge-work-plugins'
  - .claude/settings.json
  - .claude/hooks/session-start.sh
  - .claude/hooks/ssh-guard.sh
  - .claude/commands/
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Restructured the Claude development pipeline based on patterns from anthropics/knowledge-work-plugins:

1. **Memory restructuring** — Slimmed global CLAUDE.md from 324→99 lines (~70% token reduction per turn). Moved detailed infrastructure, credentials, GPU/AI, and project context to on-demand topic files in `~/.claude/context/`.

2. **SessionStart hook** — Auto-surfaces active backlog tasks, high-priority To Do items, and stale In Progress tasks across all 51 projects on every session start.

3. **SSH guard hook** — PreToolUse hook on Bash that blocks destructive commands (rm -rf, docker prune, DROP TABLE, shutdown, etc.) targeting production server via SSH.

4. **Five slash commands with model routing:**
   - `/deploy <service>` — Pre-flight checks + deploy to Netcup (Sonnet)
   - `/audit [project|all]` — Hardcoded secrets + Infisical integration scan (Haiku+Sonnet)
   - `/quick-check <type>` — Fast infra validation: DNS, containers, compose (Haiku)
   - `/plan <topic>` — Architecture decisions with structured output (Opus)
   - `/status` — Full infrastructure dashboard (Haiku)

5. **Cost-tiered model routing** — Haiku for cheap validation (~$0.005), Sonnet for analysis (~$0.02-0.05), Opus for complex reasoning (~$0.10+).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Global CLAUDE.md slimmed to ~100 lines with context lookup table
- [x] #2 Topic files created in ~/.claude/context/ (credentials, infrastructure, gpu-and-ai, projects)
- [x] #3 SessionStart hook surfaces active tasks and stale items
- [x] #4 SSH guard hook blocks destructive production commands
- [x] #5 Five slash commands created: deploy, audit, quick-check, plan, status
- [x] #6 Model routing documented: Haiku for validation, Sonnet for analysis, Opus for planning
- [x] #7 All files committed and pushed to main
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented full Claude Code pipeline improvement based on anthropics/knowledge-work-plugins patterns. Memory restructuring saves ~70% base context tokens per session. Hooks provide automatic task surfacing and production safety guards. Five slash commands with cost-tiered model routing enable efficient ops workflows. Committed as ebd90f4, pushed to main and dev.
<!-- SECTION:FINAL_SUMMARY:END -->
