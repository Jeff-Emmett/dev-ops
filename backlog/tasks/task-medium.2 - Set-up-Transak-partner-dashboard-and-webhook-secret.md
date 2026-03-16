---
id: TASK-MEDIUM.2
title: Set up Transak partner dashboard and webhook secret
status: To Do
assignee: []
created_date: '2026-03-16 04:48'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Transak API key is set ([in Infisical]) but TRANSAK_WEBHOOK_SECRET is empty.
Steps:
1. Log into Transak partner dashboard
2. Configure webhook URL pointing to payment-onramp service
3. Copy webhook secret to Infisical and update onramp-service .env
4. Test with Base Sepolia USDC on-ramp flow
Service: payment-onramp container (port 3002, running)
<!-- SECTION:DESCRIPTION:END -->
