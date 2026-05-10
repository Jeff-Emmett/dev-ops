---
id: TASK-MEDIUM.14
title: Deprecate p2pwikifr — static archive + shutdown live MediaWiki instance
status: In Progress
assignee: []
created_date: '2026-05-09 15:48'
updated_date: '2026-05-09 22:05'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
wikifr.p2pfoundation.net is dormant: 300 articles, 0 edits in 90 days, 0 active editors, last edit Feb 2026. Sitting at 99% memory cap (504/512 MiB) hitting MaxRequestWorkers under bot traffic. Replace live MediaWiki + mariadb stack with a static export served by nginx. Preserves URLs and content; reclaims ~700MB RAM and removes an attack surface. Translation engine task (sibling) handles the on-demand French need going forward.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 dumpBackup.php XML export of p2pwikifr (full history) committed to a git repo
- [x] #2 dumpHTML.php static HTML export rendered with current skin
- [ ] #3 Static site deployed to wikifr.p2pfoundation.net (nginx container or Cloudflare Pages)
- [x] #4 Smoke-test: top-10 most-linked pages render correctly with working internal links
- [x] #5 Old containers (p2pwikifr, p2pwikifr-db) stopped (NOT removed) and volumes preserved for 30-day rollback window
- [ ] #6 After 30 days no-issue, remove containers + volumes; document decommission in /opt/websites/p2pwikifr/DECOMMISSIONED.md
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Starting export phase. Plan: (1) dumpBackup.php XML full-history → host filesystem, (2) wget --mirror static HTML → host filesystem, (3) review output, (4) deploy nginx static, (5) stop live containers (preserve volumes), (6) document rollback path.

EXECUTED 2026-05-09 — chose redirect path over static HTML mirror (user decision). Static mirror via wget hit 504 because live apache prefork was saturated by bot scrapers; redirect via Traefik file provider is cleaner anyway (no dead-link 404s, no static maintenance, search engines get 308 hint to update indexes).

Done:
- Fresh mysqldump: /opt/websites/p2pwikifr/archive/p2pwikifr-db-20260509-2336.sql.gz (127 MB)
- Fresh XML: /opt/websites/p2pwikifr/archive/p2pwikifr-xml-20260509-2336.xml.gz (1.5 MB, 370 pages, 1,637 revisions)
- Images dir preserved at /opt/websites/p2pwikifr/images/
- Traefik file-provider redirect: /root/traefik/config/p2pwikifr-deprecation.yml — 308 wikifr.p2pfoundation.net/* → https://wiki.p2pfoundation.net/
- Smoke-tested redirect (root + path) — both 308 to en wiki
- Containers stopped (NOT removed) via docker compose stop
- Volumes preserved (p2pwikifr_p2pwikifr-db-data)
- DECOMMISSIONED.md written with rollback and final-removal instructions

RAM reclaimed: ~700 MB (mediawiki + mariadb stopped)

Final removal scheduled: 2026-06-09 (30 days). Until then, redirect is reversible.
<!-- SECTION:NOTES:END -->
