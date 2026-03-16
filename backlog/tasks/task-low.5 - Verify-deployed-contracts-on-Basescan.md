---
id: TASK-LOW.5
title: Verify deployed contracts on Basescan
status: To Do
assignee: []
created_date: '2026-03-16 04:48'
labels: []
dependencies: []
parent_task_id: TASK-LOW
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Contracts deployed to Base Sepolia need verification for transparency:
- MycoToken: 0x71eD7Fc3c3DE12a3966CA61B996c326504533A20
- MycoBondingCurve: 0x0361534B617C54E50E97DfE6936A3CDD3afC61ff
- PaymentSplitter: 0xcc4840eaDAeE001a8dfB020C6767Eb0Fd7ebf181
- CRDTToken: 0xEAc578d1aF84943a8FF760462D767670157DdeA4 (from earlier)
- USDCEscrow: 0x1Fb0EB7e4D098FF6cECc09b629fBd6CFC6Db5d1f (from earlier)
Needs BASESCAN_API_KEY — get free key at basescan.org/apis.
Then: cd /opt/apps/payment-infra/contracts && npx hardhat verify --network baseSepolia <address> <constructor-args>
<!-- SECTION:DESCRIPTION:END -->
