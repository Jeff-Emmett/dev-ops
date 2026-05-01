---
id: TASK-76
title: 'payment-forge Phase 8 — bank rails (Plaid ACH routing, non-custodial)'
status: To Do
assignee: []
created_date: '2026-05-01 00:23'
updated_date: '2026-05-01 03:24'
labels:
  - forge
  - payments
  - ach
  - plaid
  - fintech
dependencies:
  - TASK-71
  - TASK-74
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Phase 8 of payment-forge** (TASK-71 umbrella). Enhances fiat path with Plaid for richer ACH-based onramp routing — still strictly non-custodial.

## Approach

Plaid Link gives users a way to authorize bank-account → onramp-partner ACH pulls *without* the partner needing to handle bank credentials. Forge uses Plaid token exchange purely as a UX upgrade for the Phase 6 referral flow — funds still flow user-bank → partner → user-wallet, never through us.

## Why this is Phase 8 not Phase 6

Plaid integration adds compliance scope (data privacy, SOC2-ish posture) even when funds aren't held. Worth doing only after Phase 6 validates fiat-rail demand.

## Non-goals

- Holding Plaid access tokens long-term (use ephemeral exchange where possible)
- Direct ACH initiation by forge (NEVER — that's MTL territory)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Plaid Link integrated; user can connect bank for onramp partner consumption
- [ ] #2 Plaid public-token → access-token exchange runs short-lived (no long-term storage)
- [ ] #3 Phase 6 onramp path now offers ACH-via-Plaid as a sub-rail with reduced fees
- [ ] #4 Compliance review: data handling documented, no banking credentials persisted, partner-side ACH initiation only
- [ ] #5 Off-ramp path supports ACH disbursement via partner (same non-custodial constraint)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**Status (2026-04-30 review)**: Deferred. Three external prerequisites not yet satisfied:

1. **Browser-side Plaid Link integration is a consumer UI concern.** Plaid Link is a JS widget that runs in the user's browser and produces a `public_token`. Without an active consumer (rspace-online, etc.) committing to the Plaid Link UI, building the server-side exchange ahead of it produces dead code — no way to exercise the round-trip.
2. **Plaid sandbox account + API keys not provisioned.** The full Phase 8 server work (token exchange, ACH-via-Plaid sub-rail composition) requires real Plaid credentials. Sandbox is free but needs account signup.
3. **Underlying onramp partner integration.** Plaid alone doesn't move funds — the ACH pull is initiated by Transak / Onramper / similar after they receive the Plaid access token. Partner support for "ACH-via-Plaid" varies; needs research per partner.

Phase 6 (TASK-74) Transak/Onramper rails are already in place. Adding Plaid as a sub-rail is a small extension once the three prerequisites are satisfied — likely 1–2 days of focused work.

**Recommend revisiting** when:
- A consumer commits to a UI flow that includes bank-connect via Plaid
- Plaid sandbox credentials are in Infisical
- The chosen onramp partner has documented Plaid integration

Until then, the existing fiat-referral rails (Transak / Onramper widgets) handle the same use case via the partner's own bank-connect UI. Plaid is a UX upgrade, not a missing capability.
<!-- SECTION:NOTES:END -->
