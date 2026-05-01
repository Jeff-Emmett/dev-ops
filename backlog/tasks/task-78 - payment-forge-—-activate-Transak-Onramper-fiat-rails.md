---
id: TASK-78
title: payment-forge — activate Transak + Onramper fiat rails
status: To Do
assignee: []
created_date: '2026-05-01 04:34'
labels:
  - payment-forge
  - fiat
  - transak
  - onramper
  - activation
dependencies:
  - TASK-71
  - TASK-74
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Activate the Transak + Onramper rails that ship in null-quote stub mode (TASK-74). Both rail factories already exist at `~/Github/payment-forge/src/rails/{transak,onramper}.ts` and register but null-quote until their partner API keys are configured.

## External prereqs (sequence)

1. **Sign Transak partner agreement** at https://transak.com/partner — get `apiKey` (public-by-design) for production and a separate one for staging.
2. **Sign up at Onramper** https://onramper.com/partners — get aggregator API key.
3. **Decide default fiat currencies** — typically `USD` for US users, `EUR` for EU. Per-request override always wins.
4. **Decide default wallet address policy** — usually inherit from `holon.signerSet.address` per quote; only set a `defaultWalletAddress` if the consumer doesn't have a holon context.

## Activation steps

```bash
# In Infisical project payment-forge (TASK-77 prereq):
TRANSAK_PARTNER_API_KEY=<from transak partner dashboard>
TRANSAK_ENVIRONMENT=production            # or staging for dev
ONRAMPER_API_KEY=<from onramper dashboard>
TRANSAK_ESTIMATED_FEE_BPS=100              # optional, defaults to 100
ONRAMPER_ESTIMATED_FEE_BPS=75              # optional, defaults to 75
```

Server's `setupDefaultRails()` reads these and conditionally registers when present (no code change needed once the auto-registration wiring lands).

## Webhook handler (Phase 6b)

When ready to capture transaction-completed events:
- Transak: `POST /api/forges/payment-forge/webhooks/transak` — verify HMAC signature, store opaque event ID + timestamp, no PII.
- Onramper: similar; provider-specific signature scheme.

Both should mark the consumer's local flow record as settled.

## Acceptance criteria intent

When complete, a path like `USD → USDC on Base` should produce a Transak / Onramper widget URL via `POST /quote`, the consumer redirects user to it, partner handles KYC + payment, settlement lands in user's wallet, optional webhook informs the forge of completion.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 TRANSAK_PARTNER_API_KEY + ONRAMPER_API_KEY are present in Infisical project payment-forge under /prod path
- [ ] #2 After `docker compose restart payment-forge`, GET /rails returns transak-base + onramper-base entries
- [ ] #3 Real fiat→USDC quote against Transak / Onramper completes with a valid widget URL (manually verify URL renders the partner page)
- [ ] #4 Webhook handler endpoints accept signed callbacks and record opaque event IDs only (audit confirms no PII stored)
- [ ] #5 Off-ramp direction (USDC→USD) produces equivalent partner URLs
<!-- AC:END -->
