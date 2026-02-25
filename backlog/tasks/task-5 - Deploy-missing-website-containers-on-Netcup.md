---
id: TASK-5
title: Deploy missing website containers on Netcup
status: Done
assignee: []
created_date: '2025-12-04 06:25'
updated_date: '2026-02-13 21:41'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up containers for domains with Cloudflare IPs but no corresponding container on Netcup.

Domains to check/deploy:
- ebbnflowtherapeutics.com
- pilateswithfadia.com (may share with Fadia sites)
- cryptocommonsgather.ing
- bondingcurve.tech
- higgysandroidboxes.com
- nofi.lol
- myc0punkz.xyz (alt spelling of mycopunk)

For each: check if repo exists locally, deploy content if available, otherwise create placeholder "Coming Soon" page.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ebbnflowtherapeutics.com has container or redirect
- [x] #2 pilateswithfadia.com has container or redirect
- [x] #3 cryptocommonsgather.ing has container or redirect
- [x] #4 bondingcurve.tech has container or redirect
- [x] #5 higgysandroidboxes.com has container or redirect
- [x] #6 nofi.lol has container or redirect
- [x] #7 myc0punkz.xyz has container or redirect
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
myc0punkz.xyz deployed: container running on Netcup, DNS switched from DO to Cloudflare tunnel, tunnel config updated via API. Site live (HTTP 200).

nofi.lol deployed: satirical anti-finance site built with Next.js static export + nginx. Container running on Netcup, DNS updated to Cloudflare tunnel, tunnel config updated via API.

4 sites verified deployed on Netcup with HTTP 200:
- pilateswithfadia.com: deployed container running
- cryptocommonsgather.ing: deployed container running
- bondingcurve.tech: deployed container running
- higgysandroidboxes.com: deployed container running

ebbnflowtherapeutics.com (HTTP 401): This is a Squarespace private/reserved site - not deployed by us on Netcup. Marked incomplete as it's not a deployment candidate.

All 5 sites verified running and returning HTTP 200: mycofi.earth, rspace.online, alltor.net, higgys.org, rtrips.online
<!-- SECTION:NOTES:END -->
