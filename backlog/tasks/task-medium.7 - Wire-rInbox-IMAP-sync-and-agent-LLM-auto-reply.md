---
id: TASK-MEDIUM.7
title: Wire rInbox IMAP sync and agent LLM auto-reply
status: To Do
assignee: []
created_date: '2026-03-16 04:55'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two rInbox features are placeholder-only:

1. Personal inbox IMAP sync loop — API endpoints exist (POST/GET/DELETE /api/personal-inboxes) but never tested with real IMAP credentials. Need to configure a test mailbox and verify the sync loop works.

2. Agent inbox auto-reply — processAgentRules() engine exists but auto-reply is a placeholder with no LLM integration. Wire to LiteLLM proxy at http://litellm:4000 (on traefik-public network) for Claude/Gemini responses.

Both in rSpace modules/rinbox/
<!-- SECTION:DESCRIPTION:END -->
