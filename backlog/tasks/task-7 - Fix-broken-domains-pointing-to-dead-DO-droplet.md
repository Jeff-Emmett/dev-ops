---
id: task-7
title: Fix broken domains pointing to dead DO droplet
status: In Progress
assignee: []
created_date: '2025-12-04 06:25'
updated_date: '2025-12-04 06:26'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
These domains are currently pointing to the old DigitalOcean droplet (143.198.39.165) which is now offline:

- fadiaelgharib.com
- crypto-commons.org

Need to either:
1. Deploy containers on Netcup and point through tunnel
2. Set up redirects to other domains
3. Create placeholder pages
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 fadiaelgharib.com is accessible (container or redirect)
- [ ] #2 crypto-commons.org is accessible (container or redirect)
<!-- AC:END -->
