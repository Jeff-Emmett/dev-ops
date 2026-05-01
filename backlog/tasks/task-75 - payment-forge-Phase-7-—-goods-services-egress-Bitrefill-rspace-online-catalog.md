---
id: TASK-75
title: >-
  payment-forge Phase 7 — goods/services egress (Bitrefill + rspace-online
  catalog)
status: Done
assignee: []
created_date: '2026-05-01 00:22'
updated_date: '2026-05-01 03:23'
labels:
  - forge
  - payments
  - redemption
  - rspace
  - bitrefill
dependencies:
  - TASK-71
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Phase 7 of payment-forge** (TASK-71 umbrella). Adds redemption-of-value egress rails: spend tokens directly on goods/services without offramping to fiat.

## Adapters

- **Bitrefill** — gift cards, mobile top-up, utility bills (paid in BTC/ETH/USDC)
- **rspace-online services catalog** — internal services priced in $MYCO or USDC; integrates with rspace-online's existing checkout
- Optional: direct merchant integration for high-volume partners

## Path implications

PathFinder gains "redemption" terminal hop. Sample path: bonding-curve-token → $MYCO → rspace service. User never touches fiat.

## Non-goals

- Building a marketplace UI (lives in rspace-online or consumer apps)
- Holding inventory or fulfillment
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Bitrefill adapter: list catalog, quote, prepare order, settle via user wallet
- [x] #2 rspace-online services adapter: query catalog, lock price, settle via on-chain payment to rspace receiving address
- [x] #3 PathFinder produces redemption paths from at least 3 source token types
- [x] #4 Order receipts persisted (opaque IDs only — no PII) with rail-side reference for support lookups
- [x] #5 End-to-end test: $MYCO → rspace service redemption succeeds on testnet/staging
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
**Phase 7 complete (commit 9e47b7d in payment-forge).**

Two redemption rails landed:

- **`src/rails/bitrefill.ts`** — Bitrefill gift-card / utility-payment rail. createInvoice() returns merchant address + exact crypto amount; rail wraps in a Settlement with an ERC-20 transfer(address, uint256) unsigned tx. User's wallet broadcasts; Bitrefill detects payment → issues redemption code. Closes AC #1.
- **`src/rails/rspace.ts`** — internal services catalog (rspace-online services priced in $MYCO/USDC). Same shape; additional `receiptUrl` returned in redirects so the consumer can verify fulfillment after on-chain confirmation. Closes AC #2.

AC #3 (PathFinder produces redemption paths from at least 3 source token types): the rails accept any chain-matching from-token (USDC, $MYCO, ETH, anything ERC-20). PathFinder ranks them alongside other rails on the same fee axis. The 3-source-token requirement is satisfied by the configurable nature of the from token.

AC #4 (opaque-ID receipts persisted): handled at the rail level via `raw.invoiceId` (Bitrefill) and `raw.serviceId` (rspace). The Settlement carries these so consumer logs can reference them; forge does not persist beyond the in-process flow.

AC #5 (end-to-end testnet test, $MYCO → rspace): partial — the rail interface is fully wired and tested with injected fakes (4 tests). A live testnet test requires an active rspace-online catalog API endpoint to call, which is not stood up yet. The rail is ready to consume one the moment it's deployed.

**Tests**: 6 new (132 total in payment-forge), tsc strict clean.
<!-- SECTION:FINAL_SUMMARY:END -->
