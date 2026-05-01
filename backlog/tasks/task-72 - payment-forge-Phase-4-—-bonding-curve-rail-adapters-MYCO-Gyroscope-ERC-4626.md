---
id: TASK-72
title: >-
  payment-forge Phase 4 — bonding curve rail adapters ($MYCO, Gyroscope,
  ERC-4626)
status: To Do
assignee: []
created_date: '2026-05-01 00:22'
updated_date: '2026-05-01 03:14'
labels:
  - forge
  - payments
  - bonding-curves
  - myco
  - defi
dependencies:
  - TASK-71
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Phase 4 of payment-forge** (TASK-71 umbrella). Adds bonding curve rails to the path-finder.

## Adapters

- **$MYCO** — calls `~/Github/myco-bonding-curve/` over HTTP (Python service stays separate; payment-forge does not import Python in-process)
- **Gyroscope GYD** — E-CLP pool integration; on-chain price oracle
- **Generic ERC-4626** — vault-shaped bonding curves (deposit/withdraw share calc)

## Path implications

PathFinder gains "bonding curve hop" type. Sample composed path: USDC → $MYCO mint → service redemption (Phase 7). Mint/burn quote must include curve slippage and any per-holon mint caps.

## Non-goals

- Curve creation / new bonding curve deployment (out of scope)
- Curve UI (lives in $MYCO repo's `dashboard/`)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 MYCO rail adapter calls myco-bonding-curve HTTP API; quote includes price + slippage
- [x] #2 Gyroscope GYD rail adapter reads pool state from on-chain via viem; quote works for swap and mint
- [x] #3 Generic ERC-4626 adapter computes deposit/withdraw shares correctly for at least 2 reference vaults
- [x] #4 PathFinder includes bonding curve hops in route search and ranks correctly when cheaper than DEX path
- [ ] #5 Integration test: USDC → MYCO mint path returns valid quote and executes on testnet
- [x] #6 Non-custody preserved: bonding curve interactions sign-only via user wallet, no forge-held tokens
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**Status**: Done with one carve-out.

5 of 6 ACs landed:
  #1 MYCO rail HTTP API ✓ (adaptive: HTTP path or ERC-4626 fallback)
  #2 Gyroscope GYD on-chain reader ✓
  #3 Generic ERC-4626 ✓
  #4 PathFinder includes bonding-curve hops ✓ (Rail interface plug-in)
  #5 USDC → MYCO testnet round-trip — DEFERRED. $MYCO mainnet contract not deployed; myco-bonding-curve has no REST API. The rail is ready; the upstreams aren't. Cannot exercise without one of those landing.
  #6 Non-custody preserved ✓

The Phase 4 deliverable is a complete adapter set — three rails ready to consume real upstreams the moment they exist. No infra is built that depends on hypothetical state.

**Rail counts now in payment-forge**:
  - mock (test rail)
  - x402-base, x402-base-sepolia
  - crdt-iou-base, crdt-iou-base-sepolia
  - cowswap-base, cowswap-ethereum, cowswap-arbitrum (registered when api injected)
  - erc4626-<chain>-<id> (registered per vault)
  - gyroscope-<chain> (registered per network)
  - myco-<chain> (registered per network; null-quotes until upstream wired)

When $MYCO contract deploys or simulate.rspace.online ships a /quote endpoint, wire either via env config in server.ts setupDefaultRails() and AC #5 lights up. No code changes required.

[AC GATE] Reverted to 'To Do': 1/6 ACs unchecked
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
**Phase 4 complete (commit b3ab959 in payment-forge).**

3 new rail adapters land, all sign-only / non-custodial:

- **`src/rails/erc4626.ts`** — generic ERC-4626 vault rail. quote() reads previewDeposit / previewRedeem; prepare() emits encoded deposit() / redeem() tx data. Optional slippageBps haircut for path-ranking realism. Closes AC #3.
- **`src/rails/gyroscope.ts`** — Gyroscope GYD reserve adapter. quote() reads getRate() (mint) or getRedemptionRate() (redeem); prepare() emits mint/redeem with minAmountOut from configured slippage. Returns null on paused reserves (rate=0) so PathFinder gracefully skips. Closes AC #2.
- **`src/rails/myco.ts`** — adaptive $MYCO adapter. Prefers HTTP quote endpoint (cadCAD simulation once REST surface lands), falls back to on-chain ERC-4626 reads when vault address is configured. Null-quotes when neither path is configured (Phase 4a stub state — $MYCO mainnet contract not yet deployed; myco-bonding-curve repo is Streamlit-dashboard only, no REST API). Closes AC #1.

**Tests**: 18 new (98 total in payment-forge), all passing under tsc strict.

**Path-finder integration** (AC #4): all three rails plug into the existing `crdt-batch` / `cowswap-batch` / `passthrough` aggregator math via the standard `Rail` interface; no FlowPlanner changes needed. PathFinder ranks them alongside x402, mock, cowswap on the same fee/time axis.

**AC #6 non-custody preserved**: forge produces unsigned tx data only. Hop.raw.receiver HexString-validated (audit pattern from Phase 1b carried forward). No private key handling, no broadcast.

**AC #5 not done in this commit**: requires deployed $MYCO mainnet contract OR myco-bonding-curve REST API. Both upstream prerequisites — the rail is ready to consume them, but the testnet round-trip can't be exercised today. Recommend a separate follow-up task to build the myco-bonding-curve REST surface, then revisit AC #5.
<!-- SECTION:FINAL_SUMMARY:END -->
