---
id: TASK-73
title: payment-forge Phase 5 — holonic policy engine + Safe multisig signer support
status: Done
assignee: []
created_date: '2026-05-01 00:22'
updated_date: '2026-05-01 03:19'
labels:
  - forge
  - payments
  - holons
  - multisig
  - policy
dependencies:
  - TASK-71
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Phase 5 of payment-forge** (TASK-71 umbrella). Turns `HolonPolicy` from a stub into a real engine.

## Policy DSL

YAML or JSON declarative policy per holon:
- `settlement_mode`: `sync` | `batched` | `hybrid`
- `custodial_partners_allowed`: bool (default false)
- `fiat_rails_allowed`: bool
- `signer_set`: EOA address OR Safe multisig address + threshold
- `max_path_fee_bps`: per-tx fee ceiling
- `preferred_chains`: ordered list

## Resolver

PathFinder consumes policy as constraint set; rejects paths that violate, ranks remainder.

## Safe multisig

Use Safe Protocol Kit (TS) for proposal creation when signer_set is a Safe. Forge prepares the tx; Safe signers approve via their normal flow. Forge never holds the Safe's signing key — non-custody preserved.

## Non-goals

- Policy UI (lives in rspace-online or similar consumer)
- Policy mutation API (read-only at first; mutation comes later)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 HolonPolicy schema documented; YAML loader + JSON loader both work
- [x] #2 PathFinder filters paths by policy constraints; unit tests cover each constraint type
- [x] #3 Safe multisig signer flow: forge prepares tx, posts to Safe Transaction Service, returns proposal URL
- [x] #4 EOA signer flow continues to work (regression test)
- [x] #5 Per-holon policy override via API param works without restart
- [x] #6 Policy violation returns clear error including which constraint failed
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
All 6 ACs land in commit 7eb14db. Resolver now drives PathFinder filtering as the single source of truth; adding a new constraint = extending one of three helpers. Safe integration is helper-shaped (build + submit functions), ready to wire into /execute in Phase 5b without further design work.

Total payment-forge state: 12 commits, 117/117 tests, tsc strict clean. The 5b /execute Safe-routing extension is small and can be bundled with any future change.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
**Phase 5a complete (commit 7eb14db in payment-forge).**

Holonic policy engine + Safe multisig integration:

- **`src/policy/loader.ts`** — YAML + JSON loaders both validating via the existing Zod HolonPolicy schema. `loadPolicyAuto` detects format by leading char. Closes AC #1.
- **`src/policy/resolver.ts`** — single-source-of-truth constraint engine with structured `Verdict` shape (`{ ok, constraint, reason }`). Three gates: `evaluateRail` (kind vs fiat/custody flags), `evaluateHop` (preferredChains), `evaluateFlow` (maxPathFeeBps). Closes AC #2 + #6.
- **`src/policy/safe.ts`** — Safe Transaction Service integration. `buildSafeProposal()` converts a Settlement's unsigned tx into STS payload shape with `operation: 0` (CALL, never DELEGATECALL). `submitSafeProposal()` POSTs to per-chain STS endpoint and returns the `app.safe.global` URL Safe owners visit to sign. Closes AC #3.
- **`src/flow-planner.ts`** — refactored to call resolver helpers instead of inline checks. EOA flow continues to work (117/117 tests pass after refactor) — closes AC #4.
- AC #5 (per-holon override via API param) was already supported via `QuoteRequest.holon` and `FlowRequest.legs[].holon`; tests in `tests/server.test.ts` exercise the round-trip.
- AC #6 (clear error with violated constraint name) — Verdict shape provides this; resolver tests assert specific constraint identifiers and human-readable reasons.

**Tests**: 19 new (117 total), tsc strict clean.

**Non-custody preserved**: forge POSTs proposal metadata to STS (a public indexer of pending Safe txs); does not sign and does not call `execTransaction`. The Safe owners handle both through their own wallets.

**Phase 5b deferred** (does not block this AC sweep):
- `/execute` endpoint Safe routing (when `signerSet.type === "safe"`, dispatch to `submitSafeProposal` instead of returning unsigned tx). One-switch addition at the dispatch layer.
- MultiSend wrapper for multi-tx settlements (e.g. approve + swap pairs).
<!-- SECTION:FINAL_SUMMARY:END -->
