---
id: TASK-38
title: Wire remaining Tier 1 custom apps to Infisical (12 services)
status: To Do
assignee: []
created_date: '2026-02-23 20:00'
updated_date: '2026-02-23 20:00'
labels: [infisical]
dependencies: ['TASK-34']
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate remaining custom apps to Infisical. Same pattern for each: create project → push secrets → add entrypoint → modify compose → deploy.

Services:
1. clip-forge (Python, WireGuard — needs external INFISICAL_URL)
2. games-platform (Node.js)
3. grid-trading-bot (Node.js, Telegram + blockchain keys)
4. schedule-jeffemmett (Node.js, Google OAuth + SMTP)
5. open-claw-iron (Rust, may need curl+jq)
6. personal-dashboard (Node.js, many API integrations)
7. rchats-online (Node.js)
8. rcal-online (Node.js)
9. mycofi-earth-website (Node.js)
10. ai-orchestrator (Python)
11. semantic-search (Python)
12. p2pwiki-content (Python)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

- [ ] All 12 services have Infisical projects created
- [ ] All secrets migrated to respective projects
- [ ] Entrypoints added (appropriate runtime for each)
- [ ] All compose files stripped of hardcoded secrets
- [ ] All containers verified via verify-injection.sh
