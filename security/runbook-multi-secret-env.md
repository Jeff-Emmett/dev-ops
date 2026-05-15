# Runbook: rotate a multi-secret service .env (shared pattern)

**Applies to** inventory entries that are a single `.env`/stash holding
*many* independent secrets, where "rotation" means walking each value
through its own provider, not one swap:

| Inventory entry | File |
|---|---|
| `rspace-online-secrets` | `/opt/rspace-online/.env` (~52 keys) |
| `payment-infra-secrets` | `/opt/apps/payment-infra/.env` (~43 keys) |
| `pentagi-secrets` | `/opt/apps/pentagi/.env` (~29 keys) |
| `commons-hub-listmonk-secrets` | `~/.secrets/private/commons-hub-listmonk.txt` |
| `rmesh-holonserve-secrets` | `~/.secrets/private/rmesh-holonserve.env` |
| `katheryn-website-secrets` | `/opt/secrets/katheryn-website/.env` |
| `worldplay-admin` | `/opt/secrets/worldplay/.env` |

> These are *bundles*. Don't "rotate the bundle" — triage the keys
> inside it. Most keys delegate to a more specific runbook (Stripe →
> `runbook-stripe-crypto-commons.md`, an external API key →
> `runbook-external-api-key.md`, a DB password → the Postgres pattern,
> a Mailcow SMTP pw → `runbook-mailcow-mailbox.md`).

## Procedure

### 1. Enumerate + classify the keys
```bash
ssh netcup-full 'grep -E "^[A-Z_]+=" <FILE> | sed "s/=.*//"'
```
For each key decide: provider-portal key, DB password, signing secret,
SMTP pw, or non-secret (URL/flag — skip). Write the classification into
the inventory entry's `notes:` the first time you do this so the next
rotation is mechanical.

### 2. Rotate per class (highest blast-radius first)
- **Signing/JWT/APP secrets** (`*_SECRET`, `APP_SECRET`, `JWT_*`):
  generate `openssl rand -hex 32`, swap, restart. Invalidates sessions —
  schedule + communicate.
- **DB passwords**: Postgres pattern + the consumer-verification check
  (`postgres-profiles/README.md`; memory
  `postgres_rotation_consumer_verification`). Split-config → lockstep.
- **Provider API keys**: `runbook-external-api-key.md`.
- **Stripe / payment**: `runbook-stripe-crypto-commons.md` (payment-infra
  especially — real money; rotate restricted keys, roll webhook secret).
- **SMTP**: `runbook-mailcow-mailbox.md`.

Always: `cp <FILE> <FILE>.bak.$(date -u +%Y%m%d-%H%M%S)` before edits;
restart the consumer with `docker compose up -d --force-recreate` so it
re-reads; verify the **consumer** (logs / health endpoint), not just the
upstream.

### 3. Smoke test the whole service
Hit the service's health/main endpoint; tail its logs for auth errors
across all subsystems (a multi-secret env means multiple failure
surfaces).

### 4. Record
```bash
cd ~/Github/dev-ops && ./security/mark-rotated.sh <entry>
git add security/secrets-inventory.yaml && git commit -m "security: rotate <entry>"
```

## Why one runbook
The *pattern* (enumerate → classify → delegate per class → consumer
smoke test) is identical; only the key list differs and that lives in
each entry's `notes:`. Writing 7 near-identical files would be the
redundancy the project style guide warns against.

## Cross-references
`runbook-external-api-key.md`, `runbook-stripe-crypto-commons.md`,
`runbook-mailcow-mailbox.md`, `runbook-listmonk-postgres.md`,
`postgres-profiles/README.md`.
