---
id: TASK-80
title: 'payment-forge — activate bonding curve rails (Gyroscope, ERC-4626, $MYCO)'
status: To Do
assignee: []
created_date: '2026-05-01 04:35'
labels:
  - payment-forge
  - bonding-curves
  - myco
  - gyroscope
  - activation
dependencies:
  - TASK-71
  - TASK-72
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Activate the bonding curve rails (null-quote stubs from TASK-72). Three sub-tracks with independent prereqs:

## Track A — Gyroscope GYD

Gyroscope's GYD reserve is deployed on multiple chains. Public reserve addresses (verify against gyro.fi/docs before each new chain):
  - Optimism: 0x... (look up at app.gyro.finance)
  - Polygon ZkEVM, Arbitrum, others as Gyro launches

Activation:
```bash
# Infisical:
BASE_RPC_URL=<from Alchemy/Infura/public RPC>
GYROSCOPE_RESERVE_BASE=<address from gyro.fi when deployed on Base>
GYROSCOPE_GYD_BASE=<GYD token address>
GYROSCOPE_INPUT_BASE=<input asset, typically USDC>
```

When deployed on Base, server.ts auto-registers `gyroscope-base` rail.

## Track B — Generic ERC-4626 vaults

For each vault you want exposed as a rail, register one entry:
```bash
ERC4626_VAULTS_JSON=[
  {"chain":"base","address":"0x...","idSuffix":"morpho-usdc","slippageBps":10},
  {"chain":"base","address":"0x...","idSuffix":"yearn-eth"}
]
```

Server parses the JSON, registers one rail per entry. Sample vaults to start:
  - Morpho Blue USDC vault on Base
  - Yearn V3 vaults on mainnet/optimism
  - Aave's aTokens (technically ERC-4626 in v3+)

## Track C — $MYCO

Two paths to activation:

1. **HTTP path** — myco-bonding-curve repo ships a `/api/quote` REST endpoint that accepts a QuoteRequest body and returns a Hop. This requires adding a REST surface to the existing Streamlit/cadCAD repo.

2. **On-chain path** — $MYCO contract deploys as ERC-4626 (or compatible bonding curve) on Base. Configure via:
   ```bash
   MYCO_VAULT_ADDRESS_BASE=<once deployed>
   MYCO_ASSET_ADDRESS_BASE=<underlying, typically USDC>
   ```

Either path activates `myco-base` rail. The mycoRail factory already supports both via `httpEndpoint` or `vaultAddress` opts.

## Acceptance criteria intent

PathFinder includes bonding curve hops in route search when curves are configured; quotes execute correctly against real on-chain state for at least Gyroscope + one ERC-4626 vault; $MYCO rail activates once contract deploys or HTTP API ships.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 BASE_RPC_URL set in Infisical; payment-forge can read on-chain state via injected viem PublicClient
- [ ] #2 Gyroscope GYD rail registered for at least one chain where reserve is deployed; quote returns real rate from on-chain getRate()
- [ ] #3 At least 2 ERC-4626 vaults configured via ERC4626_VAULTS_JSON; both produce valid previewDeposit / previewRedeem quotes
- [ ] #4 $MYCO rail activated via either HTTP endpoint or vault address; quote returns price + slippage
- [ ] #5 Integration test: USDC → ERC-4626 vault deposit path produces valid unsigned tx that executes on testnet
<!-- AC:END -->
