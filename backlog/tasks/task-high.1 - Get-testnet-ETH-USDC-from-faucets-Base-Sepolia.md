---
id: TASK-HIGH.1
title: Get testnet ETH + USDC from faucets (Base Sepolia)
status: To Do
assignee: []
created_date: '2026-03-16 04:48'
labels: []
dependencies: []
parent_task_id: TASK-HIGH
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Manual browser visits needed:
1. Alchemy faucet (alchemy.com/faucets/base-sepolia) — send ETH to both:
   - Deployer: 0xC172Ff43475235e1afA50f5F4D5Cbc2D3A85BfE9 (currently ~0.000035 ETH)
   - NLA Oracle: 0x2d2E0a49B733E3CBB2B6C04C417aa5E24cd2A70F (currently ~0.000035 ETH)
2. Circle faucet (faucet.circle.com) — send USDC on Base Sepolia to deployer 0xC172Ff43475235e1afA50f5F4D5Cbc2D3A85BfE9
   Needed to test CRDT escrow deposit flow and Transak integration.
Both wallets nearly empty after contract deployments.
<!-- SECTION:DESCRIPTION:END -->
