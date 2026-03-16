---
id: TASK-MEDIUM.3
title: Deploy LSP0/LSP6 implementation contracts on Base Sepolia
status: To Do
assignee: []
created_date: '2026-03-16 04:48'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The encryptid-up-service is deployed and running at up.encryptid.jeffemmett.com but cannot create Universal Profiles yet because the LSP0 (ERC725Account) and LSP6 (KeyManager) implementation contracts are not deployed on Base Sepolia.
Steps:
1. Get testnet ETH (see faucet task)
2. Deploy LSP0 implementation via @lukso/lsp-smart-contracts factory
3. Deploy LSP6 implementation
4. Update .env with LSP0_IMPLEMENTATION and LSP6_IMPLEMENTATION addresses
5. Test UP creation via /api/deploy endpoint
Relay wallet: 0xC172Ff43475235e1afA50f5F4D5Cbc2D3A85BfE9 (same as deployer)
Secrets in Infisical /auth/UP_RELAY_PRIVATE_KEY and /auth/UP_JWT_SECRET
<!-- SECTION:DESCRIPTION:END -->
