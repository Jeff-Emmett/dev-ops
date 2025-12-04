---
id: task-12
title: Add status history tracking for velocity statistics in backlog-md
status: Done
assignee: []
created_date: '2025-12-04 11:26'
labels:
  - backlog-md
  - feature
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Added StatusHistoryEntry type to track status transitions with timestamps. Updated parser/serializer to read/write status_history from task frontmatter. Record status changes in backlog.ts for task creation and updates. Added velocity statistics panel to aggregator UI showing completed tasks, cycle times, and weekly throughput.
<!-- SECTION:DESCRIPTION:END -->
