---
id: TASK-HIGH.2
title: Wire rInbox Safe TX execution to treasury-service
status: To Do
assignee: []
created_date: '2026-03-16 04:55'
labels: []
dependencies: []
parent_task_id: TASK-HIGH
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
rInbox executeApproval() sends email on APPROVED status but does NOT submit on-chain Safe transactions. Treasury service already has full capability at POST /api/treasury/execute/:safeTxHash.

Steps:
1. In rSpace modules/rinbox/mod.ts, add HTTP call to treasury-service when approval threshold met
2. Treasury service is at http://payment-treasury:3006 on payment-infra_payment-network
3. Need to join rspace-online to payment-infra_payment-network (or use internal DNS)
4. Test with canvas multi-sig email shape (folk-multisig-email web component)

Key files: modules/rinbox/mod.ts (executeApproval), lib/folk-multisig-email.ts (canvas shape)
<!-- SECTION:DESCRIPTION:END -->
