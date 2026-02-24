---
id: TASK-35
title: Update CLAUDE.md with Infisical-first secret policy
status: Done
assignee: ['@claude']
created_date: '2026-02-23 20:00'
updated_date: '2026-02-23 20:00'
labels: [infisical, documentation]
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add Infisical secret management policy section to `~/.claude/CLAUDE.md` after the ACCESS & CREDENTIALS section. Covers policy rules, wiring instructions for custom and third-party services, and KeePass vs Infisical scope.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [x] Policy section added with NEVER hardcode rule
- [x] Custom service wiring instructions
- [x] Third-party service (volume-mount) wiring instructions
- [x] KeePass vs Infisical scope documented

## Notes

Completed as part of Infisical migration plan Phase 2.
