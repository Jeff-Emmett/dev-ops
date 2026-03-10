---
id: TASK-MEDIUM.1
title: 'Claude Code cross-session memory optimization — agents, MCP, project context'
status: Done
assignee: []
created_date: '2026-03-10 19:25'
updated_date: '2026-03-10 19:25'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Expanded Claude Code memory system to reduce token usage across sessions. Estimated 25-40% token savings on typical infrastructure/deployment prompts.

## Changes Made
- **Project map** (`~/.claude/context/project-map.md`): Categorized index of all 271 repos
- **MCP memory server**: Persistent knowledge graph via `@modelcontextprotocol/server-memory`
- **Specialized agents** (`~/.claude/agents/`): infra-manager, security-reviewer, deployment-tracker — each with cross-session persistent memory
- **Per-project CLAUDE.md**: dev-ops, canvas-website, rswag-online, clip-forge (backlog-md already had one)
- **Updated global CLAUDE.md**: References to all new memory features
- **Updated auto-memory MEMORY.md**: Documents the full memory/context system

## Token Savings Estimate
- Project map eliminates repo exploration: ~10-15% savings
- Per-project CLAUDE.md eliminates stack/command discovery: ~10-15% savings
- Specialized agents retain domain knowledge: ~5-10% savings
- MCP memory server for entity state: ~5% savings
- **Total estimated: 25-40% on typical multi-step infra prompts**
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Project map context file created
- [x] #2 MCP memory server registered
- [x] #3 3 specialized agents with persistent memory configured
- [x] #4 Per-project CLAUDE.md for 5 active repos
- [x] #5 Global CLAUDE.md and MEMORY.md updated
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
All components implemented 2026-03-10. MCP memory server needs session restart to activate. Per-project CLAUDE.md files are in .claude/ (gitignored globally, force-added in dev-ops). Agents store memory in ~/.claude/agent-memory/<name>/.
<!-- SECTION:NOTES:END -->
