---
id: TASK-MEDIUM.5
title: Implement Cybrid off-ramp (currently all stubs)
status: To Do
assignee: []
created_date: '2026-03-16 04:55'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
payment-offramp service has Cybrid endpoints but they are all stub/TODO implementations:
- POST /api/offramp/cybrid/initiate — returns dummy withdrawalId
- GET /api/offramp/cybrid/status/:id — returns hardcoded 'processing'
- POST /api/offramp/webhook/cybrid — acknowledges but doesn't verify

Steps:
1. Get Cybrid API credentials (CYBRID_API_KEY, CYBRID_CLIENT_ID, CYBRID_CLIENT_SECRET)
2. Implement actual withdrawal flow: create transfer quote, execute crypto transfer, Cybrid converts and sends to bank
3. Implement webhook signature verification
4. Store in Infisical
Service: payment-offramp container
<!-- SECTION:DESCRIPTION:END -->
