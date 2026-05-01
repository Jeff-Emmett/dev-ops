---
id: TASK-79
title: payment-forge — activate Bitrefill + rspace redemption rails
status: To Do
assignee: []
created_date: '2026-05-01 04:34'
labels:
  - payment-forge
  - redemption
  - bitrefill
  - rspace
  - activation
dependencies:
  - TASK-71
  - TASK-75
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Activate the Bitrefill + rspace-online catalog rails (null-quote stubs from TASK-75). Both rail factories exist at `~/Github/payment-forge/src/rails/{bitrefill,rspace}.ts` and accept an injected API client that produces real invoice/quote data.

## External prereqs

### Bitrefill
1. Sign up at https://www.bitrefill.com/business/api-access — get API username + password (HTTP Basic auth) OR API token.
2. Decide which product catalog tiers to expose (gift cards, mobile top-ups, utility bills, etc.) — Bitrefill's full catalog is large; consumer UI typically curates a subset.

### rspace-online services catalog
1. Define the services catalog schema in rspace-online (`shared/services-catalog/` or similar) — currently no `/api/services/quote` endpoint exists.
2. Pick the priced services to expose: hosted compute time, AI orchestration credits, hosted forge calls, etc.
3. Decide pricing token ($MYCO when contract deploys, USDC in the meantime).
4. Implement the `/api/services/quote` endpoint server-side in rspace-online-dev.

## Activation steps

```bash
# Infisical:
BITREFILL_API_TOKEN=<from bitrefill dashboard>
BITREFILL_BASE_URL=https://api.bitrefill.com/v2
RSPACE_CATALOG_BASE_URL=https://rspace.online/api  # once endpoint exists
```

Server's `setupDefaultRails()` reads these and registers the rails. Each rail factory takes an `api` parameter — provide a real client wrapping fetch calls to the configured base URL.

## Settlement verification (Phase 7b)

Add a verify() implementation that polls Bitrefill's order-status endpoint by invoiceId until fulfilled, and rspace's receipt URL until credited. Currently both rails return `{ ok: true }` and trust the consumer to confirm out-of-band.

## Acceptance criteria intent

A path like `USDC → gift-card-USD-50` should produce a Bitrefill invoice + ERC-20 transfer; user signs/broadcasts; Bitrefill detects payment and emails redemption code. Same pattern for rspace once their catalog API is live.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 BITREFILL_API_TOKEN present in Infisical; bitrefillRail registered after restart; GET /rails shows bitrefill-base
- [ ] #2 rspace-online ships a /api/services/quote endpoint (separate task in rspace-online-dev backlog); rspaceRail registered when RSPACE_CATALOG_BASE_URL is set
- [ ] #3 End-to-end test: USDC → gift-card redemption succeeds against Bitrefill staging or sandbox
- [ ] #4 End-to-end test: $MYCO → rspace service redemption succeeds (gated on $MYCO contract deployment per TASK-72 #5)
- [ ] #5 verify() implementations poll order/receipt status; downstream consumer records settled state
<!-- AC:END -->
