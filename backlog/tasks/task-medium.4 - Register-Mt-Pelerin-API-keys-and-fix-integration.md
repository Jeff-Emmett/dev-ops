---
id: TASK-MEDIUM.4
title: Register Mt Pelerin API keys and fix integration
status: To Do
assignee: []
created_date: '2026-03-16 04:55'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mt Pelerin (Swiss no-KYC fiat on-ramp, under CHF 1000/yr) is coded but non-functional:
1. Register at developers.mtpelerin.com, get API key + webhook secret
2. Store in Infisical: MTPELERIN_API_KEY, MTPELERIN_WEBHOOK_SECRET
3. Fix in-memory session/idempotency stores — migrate to shared Redis/Postgres persistence (same pattern as Transak in persistence.ts)
4. Fix operator signing — replace placeholder '0x' + '0'.repeat(128) with real signOperation() from operator-signer.ts
Service: payment-onramp container (port 3002)
<!-- SECTION:DESCRIPTION:END -->
