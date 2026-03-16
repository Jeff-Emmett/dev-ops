---
id: TASK-MEDIUM.6
title: Activate escrow watcher and Coinbase Onramp
status: To Do
assignee: []
created_date: '2026-03-16 04:55'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two payment-infra features ready to activate with env vars:

1. Escrow Watcher (in payment-onramp):
   Set ESCROW_CONTRACT_ADDRESS=0x1Fb0EB7e4D098FF6cECc09b629fBd6CFC6Db5d1f in .env
   Watches USDCEscrow contract for Deposited events, bridges to BFT-CRDT consensus

2. Coinbase Onramp (in payment-flow):
   Need COINBASE_CDP_KEY_ID, COINBASE_CDP_KEY_SECRET, COINBASE_CDP_PROJECT_ID
   Provides zero-fee USDC on Base — register at developer.coinbase.com
<!-- SECTION:DESCRIPTION:END -->
