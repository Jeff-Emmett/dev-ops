---
id: TASK-77
title: payment-forge deploy follow-through — Kuma monitor + Infisical wallets
status: To Do
assignee: []
created_date: '2026-05-01 03:06'
labels:
  - payment-forge
  - deploy
  - manual
dependencies:
  - TASK-71
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Final manual fill-ins for the payment-forge MVP deployment. Both are user-only because the credentials don't yet exist in scope of automation.

## 1 — Uptime Kuma monitor

UI add at https://status.jeffemmett.com → Settings → Monitors → Add New Monitor.
Spec at `dev-ops/netcup/uptime-kuma/payment-forge-monitor.md` (HTTP, /health, body keyword `"status":"ok"`, Mailcow notifications).

## 2 — Infisical project + wallet/RPC fill-in

```bash
export INFISICAL_TOKEN=<org admin>
~/Github/dev-ops/infisical/scripts/create-project.sh payment-forge
```

Then add to the new project:
- `X402_DEFAULT_PAYTO` — wallet address (activates `/demo-paywalled/*`, sets default IOU recipient)
- `BASE_RPC_URL` — for cowswap quote calls + future on-chain settlement
- `BASE_SEPOLIA_RPC_URL` — testnet equivalent
- `COWSWAP_API_KEY` — only if cow-sdk requires it for production rate limits (read-only quote endpoint typically does not)

Update `/opt/services/payment-forge/.env` on Netcup with the resulting `INFISICAL_CLIENT_ID` + `INFISICAL_CLIENT_SECRET`, then:
```bash
ssh netcup-full "cd /opt/services/payment-forge && docker compose restart payment-forge"
```

Verify:
```bash
curl https://pay.jeffemmett.com/health   # rails should still all be present
docker logs payment-forge --tail 20      # should show "[infisical-wrapper] Fetching secrets from payment-forge/prod ..."
```

Reference: `dev-ops/netcup/payment-forge-deploy.md` § Eventual Infisical provisioning.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Uptime Kuma HTTP monitor for https://pay.jeffemmett.com/health is live; visible at status.jeffemmett.com; wired to Mailcow Email Alerts notification
- [ ] #2 Infisical project `payment-forge` exists with X402_DEFAULT_PAYTO, BASE_RPC_URL, BASE_SEPOLIA_RPC_URL secrets populated
- [ ] #3 /opt/services/payment-forge/.env on Netcup contains real INFISICAL_CLIENT_ID + INFISICAL_CLIENT_SECRET
- [ ] #4 After restart, container logs show `[infisical-wrapper] Fetching secrets from payment-forge/prod`
- [ ] #5 Real Cowswap quote API call from server returns a valid quote (verifiable via `curl https://pay.jeffemmett.com/quote` with USDC↔WETH on Base)
<!-- AC:END -->
