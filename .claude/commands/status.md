---
description: Infrastructure status report
allowed-tools: Read, Glob, Grep, Bash, Task
---

# Infrastructure Status

Generate a comprehensive status report. Delegate checks to Task agents with `model: "haiku"` for cost efficiency.

## Report Sections

### 1. Backlog Summary
- Count of tasks by status (To Do, In Progress, Done)
- Any stale In Progress tasks (>3 days)
- High priority items

### 2. Git Status
- Current branch across active projects
- Any uncommitted changes
- Recent commits (last 3 days)

### 3. Server Health (if SSH available)
Run via `ssh netcup`:
- `docker ps` — running containers count and any unhealthy
- `df -h /` — disk usage
- `free -h` — memory usage
- `uptime` — load average

### 4. Service Availability
Quick HTTP checks on key endpoints:
- `gitea.jeffemmett.com`
- `secrets.jeffemmett.com` (Infisical)
- `sync.jeffemmett.com` (Syncthing)
- `backlog.jeffemmett.com`
- `mail.rmail.online`

### 5. Recent Deployments
Check deploy webhook logs if accessible.

## Output Format
Present as a concise dashboard — use tables and pass/fail indicators.
Keep it scannable. Only expand on items that need attention.
