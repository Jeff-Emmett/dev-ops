---
id: TASK-32
title: 'Implement Backlog Surfacing Agent — periodic task reminders and review prompts'
status: To Do
assignee: []
created_date: '2026-02-18 22:30'
labels:
  - feature
  - backlog
  - automation
milestone: ''
dependencies: []
references:
  - rspace-online/backlog/tasks/task-47 - Implement-System-Clock-heartbeat-service-for-rSpace-canvas.md
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build a cron-based Backlog Surfacing Agent that periodically scans all project backlogs and surfaces relevant tasks via notifications. The goal is to make the backlog a living system that proactively reminds you of what matters, rather than requiring manual review.

**Why**: Backlogs grow stale when they're write-only. Tasks get created but never resurface unless you remember to check. A surfacing agent bridges the gap between "I wrote it down" and "I acted on it."

### Architecture

Lightweight service (Docker container on Netcup or local cron):

```
┌─────────────────────────────────────────────────────┐
│              Backlog Surfacing Agent                 │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Cron Schedule:                                     │
│  ├── 09:00 daily → Morning briefing                 │
│  ├── 14:00 daily → Afternoon check-in               │
│  ├── Friday 17:00 → Weekly review summary            │
│  └── 1st of month → Monthly stale task audit         │
│                                                     │
│  Scans:                                             │
│  ├── /home/jeffe/Github/*/backlog/tasks/             │
│  └── ssh netcup "ls /opt/*/backlog/tasks/" (remote)  │
│                                                     │
│  Outputs to:                                        │
│  ├── Terminal notification (notify-send / bell)      │
│  ├── Logseq daily page (optional)                   │
│  ├── rSpace canvas shape (future, via clock service) │
│  └── Email digest (via Mailcow)                     │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Surfacing Rules

**Morning Briefing (09:00)**:
- High priority tasks across all projects
- Tasks that have been "In Progress" for > 3 days (stale warning)
- Tasks with no assignee that are high priority
- Tasks unblocked today (dependency completed yesterday)

**Afternoon Check-in (14:00)**:
- Tasks you marked "In Progress" today — still working on them?
- Any tasks that became unblocked since morning

**Weekly Review (Friday 17:00)**:
- Tasks completed this week (celebration)
- Tasks that didn't move this week (need attention?)
- New tasks created vs completed ratio
- Overdue tasks by project

**Monthly Audit (1st)**:
- Tasks older than 30 days still in "To Do" — still relevant?
- Projects with zero activity this month
- Suggest archiving or closing stale tasks

### Implementation Options

**Option A: Simple bash + cron (MVP)**
```bash
# Scan all backlogs, parse YAML frontmatter, filter by rules
# Output formatted summary to stdout or notification
*/60 9-17 * * 1-5 /opt/agents/backlog-surfacer.sh
```

**Option B: Python service with backlog CLI**
```python
# Uses `backlog task list --plain` per project
# Parses output, applies surfacing rules
# Sends via chosen notification channel
```

**Option C: Integration with rSpace clock (future)**
- Subscribe to `clock:hourly` events from rSpace System Clock (TASK-47)
- Surface tasks as shapes on a dedicated "Task Review" canvas
- Interactive — click to update status directly from canvas

### Notification Channels (implement incrementally)

1. **stdout/log file** (MVP) — just write to a file, read when needed
2. **Terminal bell / notify-send** — local desktop notification
3. **Email digest** — via Mailcow (`noreply@jeffemmett.com`)
4. **Logseq daily page** — append to today's journal
5. **rSpace canvas** — Task Review shape (requires clock service)
6. **Claude Code startup hook** — show relevant tasks when Claude starts a session

### Configuration

```yaml
# /opt/agents/backlog-surfacer/config.yml
scan_paths:
  local:
    - /home/jeffe/Github/*/backlog/
  remote:
    - netcup:/opt/*/backlog/
schedules:
  morning: "0 9 * * 1-5"
  afternoon: "0 14 * * 1-5"
  weekly: "0 17 * * 5"
  monthly: "0 9 1 * *"
notifications:
  - type: file
    path: /tmp/backlog-briefing.md
  - type: email
    to: jeff@jeffemmett.com
    from: noreply@jeffemmett.com
rules:
  stale_in_progress_days: 3
  stale_todo_days: 30
  high_priority_always_surface: true
```
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Agent scans all local project backlogs and parses task frontmatter
- [ ] #2 Morning briefing surfaces high-priority and stale tasks
- [ ] #3 Weekly review summarizes completed vs created tasks
- [ ] #4 Monthly audit flags tasks older than 30 days for review
- [ ] #5 At least one notification channel working (file or terminal)
- [ ] #6 Configurable scan paths and schedule via YAML config
- [ ] #7 Can run as Docker container on Netcup or local cron
<!-- AC:END -->
