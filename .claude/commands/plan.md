---
description: Architecture planning and infrastructure decisions using Opus
argument-hint: <topic>
allowed-tools: Read, Glob, Grep, Bash, Task
---

# Infrastructure Plan

Use this for complex architectural decisions that benefit from deep reasoning. This command uses Opus-level thinking.

## Process

1. **Gather context**: Read relevant files from `~/.claude/context/` and project-specific configs.

2. **Analyze the topic**: Consider:
   - Current infrastructure state
   - Constraints (budget, server specs, existing services)
   - Dependencies between services
   - Security implications
   - Migration path from current state

3. **Produce a structured plan**:
   ```
   ## Goal
   [What we're trying to achieve]

   ## Current State
   [What exists now]

   ## Options Considered
   [2-3 approaches with pros/cons]

   ## Recommended Approach
   [The chosen path with rationale]

   ## Implementation Steps
   [Ordered, actionable steps]

   ## Risks & Mitigations
   [What could go wrong and how to handle it]

   ## Cost Impact
   [Any changes to monthly costs]
   ```

4. **Create a backlog task** for the plan if the user approves:
   ```bash
   backlog task create "Title" --desc "..." --priority high --status "To Do"
   ```

## When to Use
- New service architecture
- Migration planning (e.g., moving services between servers)
- Cost optimization decisions
- Security architecture changes
- Multi-service integration design
