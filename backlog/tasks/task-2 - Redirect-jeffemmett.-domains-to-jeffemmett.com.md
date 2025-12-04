---
id: task-2
title: Redirect jeffemmett.* domains to jeffemmett.com
status: To Do
assignee: []
created_date: '2025-12-04 06:24'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Point all jeffemmett TLD variants (jeffemmett.lol, jeffemmett.xyz, jeffemmett.online, jeffemmett.mom) to redirect to jeffemmett.com via Cloudflare DNS redirect rules
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 jeffemmett.lol redirects to jeffemmett.com
- [ ] #2 jeffemmett.xyz redirects to jeffemmett.com
- [ ] #3 jeffemmett.online redirects to jeffemmett.com
- [ ] #4 jeffemmett.mom redirects to jeffemmett.com
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
### API Limitations (2025-12-04)

Cloudflare scoped tokens have significant limitations for redirects:
- **Page Rules API** requires Global API Key (not scoped tokens) - error: "does not support account owned tokens"
- **Dynamic Redirect Rules** require specific "Zone.Dynamic Redirect" permission
- **Bulk URL Redirects** require "Account Filter Lists:Edit" at account level
- Current tokens only have zone:read/edit, not redirect-specific permissions

### Zone IDs (for reference)
- jeffemmett.com: `45c200f8dc2a01852e41b9bb09eb7359`
- jeffemmett.lol: `cba99638982c3b73b47022d78e2445c0`
- jeffemmett.mom: `bd977684c6cc65930a766419e6cca37e`
- jeffemmett.online: `a2493d007a79da2620b0d5a903ecb1c3`
- jeffemmett.xyz: `0b265356b77509aff948cd05c1199ae6`

### Manual Dashboard Setup Required

For each domain (jeffemmett.lol, .xyz, .online, .mom):

**Option 1: Redirect Rules (Recommended)**
1. Go to Cloudflare Dashboard → Select domain
2. Navigate to: Rules → Redirect Rules → Create Rule
3. Configure:
   - Rule name: "Redirect to jeffemmett.com"
   - When: All incoming requests (expression: `true`)
   - Then: Static redirect
   - URL: `https://jeffemmett.com`
   - Status code: 301 (Permanent)
   - Preserve query string: Yes
4. Deploy

**Option 2: Page Rules**
1. Rules → Page Rules → Create Page Rule
2. URL: `*jeffemmett.lol/*`
3. Setting: Forwarding URL (301)
4. Destination: `https://jeffemmett.com/$2`

Repeat for all 4 domains (~2 min total).
<!-- SECTION:NOTES:END -->
