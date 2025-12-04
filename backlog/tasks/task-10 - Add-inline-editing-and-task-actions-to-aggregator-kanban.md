---
id: task-10
title: Add inline editing and task actions to aggregator kanban
status: Done
assignee: []
created_date: '2025-12-04 12:00'
updated_date: '2025-12-04 12:00'
labels: [backlog-md, aggregator, ui]
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Enhanced the backlog.md aggregator web GUI with inline editing capabilities and quick action buttons for task management. Added a "Won't Do" column to the kanban board.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Delete button (×) on task cards with confirmation dialog
- [x] #2 Archive button (↑) on task cards to move tasks to archive folder
- [x] #3 Won't Do column added as fourth kanban column
- [x] #4 Inline title editing (click to edit, Enter to save, Escape to cancel)
- [x] #5 Inline status dropdown to change task status
- [x] #6 Inline priority dropdown to change task priority
- [x] #7 Inline description editing when task is expanded (Ctrl+Enter to save)
- [x] #8 All changes propagate to task files and sync via WebSocket
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add archive and delete API endpoints to aggregator server
2. Add hover-activated action buttons to TaskCard component
3. Add "Won't Do" to statuses array and update grid layout
4. Implement inline editing for title with input field
5. Add status and priority dropdown selectors
6. Make description editable when expanded
7. Wire up all changes to the update API
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Completed Dec 4, 2025:

Files modified:
- /src/aggregator/web/app.tsx - Frontend kanban with inline editing
- /src/aggregator/index.ts - Backend API handlers

New API endpoints:
- POST /api/tasks/archive - Move task to archive folder
- DELETE /api/tasks/delete - Permanently delete task
- PATCH /api/tasks/update - Enhanced to support all fields (title, description, priority, labels, assignee)

UI changes:
- Action buttons appear on hover (blue ↑ for archive, red × for delete)
- Title is click-to-edit with save/cancel buttons
- Status dropdown inline on each card
- Priority dropdown with color-coded display
- Description editable when card is expanded
- Grid changed from 3 to 4 columns to accommodate Won't Do
<!-- SECTION:NOTES:END -->
