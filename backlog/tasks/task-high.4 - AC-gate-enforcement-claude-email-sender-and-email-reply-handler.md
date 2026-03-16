---
id: TASK-HIGH.4
title: 'AC gate enforcement, claude@ email sender, and email reply handler'
status: Done
assignee: []
created_date: '2026-03-16 05:35'
updated_date: '2026-03-16 05:35'
labels: []
dependencies: []
parent_task_id: TASK-HIGH
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Enforce acceptance criteria completion before tasks can be marked Done. Unified email sender (claude@jeffemmett.com) across all agents. Email reply handler that processes replies as Claude prompts.

Components:
1. AC Gate in backlog-notify.py — auto-reverts tasks to In Progress if ACs unchecked, sends [REJECTED] email
2. claude@jeffemmett.com as unified sender for backlog-notify, backlog-surfacer, kuma-alert-agent
3. backlog-reply-handler Docker agent on Netcup — polls IMAP, runs Claude CLI, emails results back
4. Email templates improved: Live URLs to Test, AC status, reply instructions
5. CLAUDE.md updated with AC gate rules (local + container)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 AC gate auto-reverts tasks with unchecked ACs and sends rejection email
- [x] #2 All agent emails sent from claude@jeffemmett.com
- [x] #3 backlog-reply-handler running on Netcup, polling IMAP every 120s
- [x] #4 Email replies processed via Claude CLI and results emailed back
- [x] #5 CLAUDE.md updated with AC gate enforcement rules
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
All components deployed and verified end-to-end. AC gate tested (TASK-64 revert/waiver cycle). Reply handler tested with live email round-trip. Committed as eb595be on dev.
<!-- SECTION:NOTES:END -->
