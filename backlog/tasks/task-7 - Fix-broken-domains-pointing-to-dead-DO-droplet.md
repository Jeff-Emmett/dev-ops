---
id: task-7
title: Fix broken domains pointing to dead DO droplet
status: Done
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
- [x] #1 fadiaelgharib.com is accessible (container or redirect)
- [x] #2 crypto-commons.org is accessible (container or redirect)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- **crypto-commons.org**: Already running on Netcup, returns HTTP 200
- **fadiaelgharib.com**: Was pointing to dead DO IP 143.198.39.165. Fixed via Cloudflare:
  - Deleted old A record (143.198.39.165)
  - Added proxied dummy A records (192.0.2.1) for @ and www
  - Added Page Rules: 301 redirect to https://pilateswithfadia.com (preserving path)
  - MX records for Cloudflare Email Routing preserved
<!-- SECTION:NOTES:END -->
