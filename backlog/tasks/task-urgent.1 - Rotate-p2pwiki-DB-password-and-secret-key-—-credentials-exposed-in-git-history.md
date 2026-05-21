---
id: TASK-URGENT.1
title: Rotate p2pwiki DB password and secret key — credentials exposed in git history
status: Done
assignee: []
created_date: '2026-04-16 12:57'
updated_date: '2026-04-16 13:00'
labels: []
dependencies: []
parent_task_id: TASK-URGENT
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
LocalSettings.php.example contained real DB password (wgDBpassword), wgSecretKey, and wgUpgradeKey that were committed to dev-ops repo. Now redacted but still in git history. Must rotate:
1. Generate new DB password, update in MariaDB and LocalSettings.php
2. Generate new wgSecretKey (64-char hex)
3. Generate new wgUpgradeKey (16-char hex)
4. Restart p2pwiki container
5. Consider git history rewrite or accept the exposure window
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Rotated all three credentials 2026-04-16. DB password updated in MariaDB + LocalSettings.php + .env. Secret key and upgrade key updated in LocalSettings.php. Wiki verified working. Committed to server repo.
<!-- SECTION:NOTES:END -->
