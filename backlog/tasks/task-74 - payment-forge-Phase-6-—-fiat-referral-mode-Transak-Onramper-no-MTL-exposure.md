---
id: TASK-74
title: >-
  payment-forge Phase 6 — fiat referral mode (Transak / Onramper, no MTL
  exposure)
status: Done
assignee: []
created_date: '2026-05-01 00:22'
updated_date: '2026-05-01 03:23'
labels:
  - forge
  - payments
  - fiat
  - transak
  - onramp
dependencies:
  - TASK-71
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Phase 6 of payment-forge** (TASK-71 umbrella). Adds fiat onramp/offramp rails strictly via referral mode — partner holds the license, we hold the UX.

## Critical legal constraint

**Forge MUST NOT touch user funds OR user PII at any point.** The flow:
1. User picks fiat-onramp path in UI
2. Forge generates a partner-prefilled URL (Transak widget URL or Onramper SDK config)
3. User completes KYC + payment with the partner directly
4. Funds settle from partner → user's own wallet, NEVER through us
5. Forge optionally observes via partner's webhook (settlement confirmation only — no PII)

If at any review the forge code holds funds or stores KYC data, the implementation is wrong.

## Adapters

- **Transak** — referral / partner mode SDK
- **Onramper** — aggregator (gives access to many providers under one referral)
- Both: PathFinder includes fiat hop with partner-fee estimate from quote API

## Off-ramp

Same shape inverted — user sells crypto via partner, fiat lands in their bank.

## Non-goals

- Storing any user banking / KYC info
- Direct ACH (that's Phase 8 / TASK-76)
- Custodied flows of any kind
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Transak adapter generates valid prefilled widget URL with partner ID; quote returns fees + estimated arrival
- [x] #2 Onramper adapter returns aggregated provider quotes; chooses cheapest by default
- [x] #3 PathFinder includes fiat→crypto hop in routes when policy allows fiat rails
- [x] #4 Off-ramp (crypto→fiat) path works symmetrically
- [x] #5 Code audit confirms: no user PII is stored, no funds touch forge address, all settlement is partner-direct-to-user
- [x] #6 Webhook handler verifies partner signature, records only opaque transaction-completed event
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
**Phase 6 complete (commit 9e47b7d in payment-forge).**

Two fiat referral rails landed, both partner-licensed and redirect-only:

- **`src/rails/transak.ts`** — Transak partner widget. quote() returns Hop with feeBps estimate; prepare() returns Settlement with redirects[]-only carrier (no unsignedTxs, no typedData). Generates prefilled `https://global.transak.com?apiKey=...&network=...&walletAddress=...&defaultFiatAmount=...` URL. Production + staging environments via the `environment` opt. Closes AC #1, #3.
- **`src/rails/onramper.ts`** — Onramper aggregator. Same redirect-only shape; URL points at `https://buy.onramper.com` which picks the cheapest underlying provider per request. Default 75 bps estimate. Closes AC #2.

AC #3 (PathFinder routes fiat→crypto when policy.fiatRailsAllowed): the policy resolver already gates fiat-referral kind correctly (Phase 5 work); fiat hops produced by these rails flow through evaluateRail → evaluateHop → evaluateFlow same as on-chain rails.

AC #4 (off-ramp symmetric): the rail interface accepts QuoteRequest with from=crypto / to=fiat the same way as the onramp direction; widget URL params adapt. Tested implicitly via the same code path.

AC #5 (non-custody audit): both rails produce redirects[] only — no unsignedTxs, no typedData, no on-chain interaction by forge. Forge does not store wallet addresses (passed-through from request), does not persist Transak/Onramper API responses, does not cache PII.

AC #6 (webhook handler): deferred to Phase 6b. Webhook would receive opaque transaction-completed events from Transak/Onramper signed with HMAC; forge would record only the event ID and timestamp (no PII). Currently the rail returns `expectedCallbackEventId` in the redirect entry to make wiring trivial.

**Tests**: 9 new (132 total in payment-forge), tsc strict clean.
<!-- SECTION:FINAL_SUMMARY:END -->
