---
id: TASK-MEDIUM.15
title: Repair Figma MCP server
status: To Do
assignee: []
created_date: '2026-05-12 21:01'
labels:
  - mcp
  - infisical
  - task-83
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Figma MCP server is configured in `~/.claude.json` pointing at `~/.claude/mcp-servers/figma/start.sh` but has never been verified end-to-end. Scaffold exists but no health check has been done; likely failing silently.

**Current state (as of 2026-05-12):**
- `~/.claude/mcp-servers/figma/` contains only `start.sh` — no `node_modules`, no committed package.json
- `start.sh` pulls `FIGMA_API_KEY` from Infisical at `workspace=5b64ec1b... env=prod path=/mcp` and execs `npx -y figma-developer-mcp --stdio`
- Auth chain: CF Access service token → Infisical universal-auth login → fetch FIGMA_API_KEY → npx Figma MCP

**Inventory ref:** `research/portable-stack/dep-inventory.md` lists Figma MCP as P2 dep. Per migration plan: KEEP Figma for legacy, Penpot for new work.

**Steps:**
1. Verify CF Access tokens present: `ls ~/.secrets/cf_access_infisical_client_id ~/.secrets/cf_access_infisical_client_secret`
2. Verify Infisical claude-mcp creds present: `ls ~/.secrets/infisical_claude_mcp_client_*`
3. Run `~/.claude/mcp-servers/figma/start.sh` manually — should emit MCP handshake JSON on stdout. Capture any errors.
4. If `FIGMA_API_KEY` missing in Infisical: generate via Figma → Settings → Account → Personal access tokens; push to Infisical at `/mcp/FIGMA_API_KEY`
5. If `figma-developer-mcp` package wrong: check current canonical Figma MCP server (likely `@modelcontextprotocol/server-figma` or the official `figma-developer-mcp` — pin a known-good version)
6. Restart Claude Code, run `/mcp` to confirm 'figma' connected (not just registered)
7. Smoke test: list files / fetch a file / read a node from a real Figma project

**Why:** Currently the Figma MCP is dead weight in the config — registered but non-functional. Either fix it or drop it from `~/.claude.json` to stop spawning a broken process at session start.

**Out of scope:** Anything Penpot-related. That's a separate migration concern under TASK-83.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 start.sh completes without error and emits valid MCP handshake
- [ ] #2 /mcp shows 'figma' as connected after Claude restart
- [ ] #3 Smoke test: list_files (or equivalent) returns at least one Figma file
- [ ] #4 FIGMA_API_KEY confirmed in Infisical at /mcp path
- [ ] #5 If unrepairable: figma entry removed from ~/.claude.json with note
<!-- AC:END -->
