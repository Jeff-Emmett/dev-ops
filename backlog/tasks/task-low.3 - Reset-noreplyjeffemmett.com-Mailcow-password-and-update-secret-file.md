---
id: TASK-LOW.3
title: Reset noreply@jeffemmett.com Mailcow password and update secret file
status: To Do
assignee: []
created_date: '2026-03-10 22:38'
labels: []
dependencies: []
parent_task_id: TASK-LOW
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
~/.secrets/private/rmail_noreply_password (32 chars) fails SMTP auth for noreply@jeffemmett.com on mail.rmail.online:587. Either the password was rotated in Mailcow without updating the local file, or the mailbox auth is misconfigured. Reset in Mailcow admin UI and update the secret file. Currently using team@rmail.online as workaround for backlog-notify.
<!-- SECTION:DESCRIPTION:END -->
