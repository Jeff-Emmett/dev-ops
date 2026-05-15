# Runbook: rotate multi-tenant service secrets (shared pattern)

**Applies to**:

| Inventory entry | Tenants / files |
|---|---|
| `twenty-multi-tenant-secrets` | `/opt/apps/twenty{,-cc,-cosmolocal,-rnetwork,-votc}/.env` + `/opt/twenty-crm/.env` |
| `postiz-multi-tenant-secrets` | `/opt/apps/postiz/.env`, `/opt/postiz/{main,bondingcurve,crypto-commons,p2pfoundation,shared-temporal}/.env` |
| `listmonk-multi-tenant-secrets` | `~/.secrets/private/listmonk-multi-tenant.txt` (the p2p/worldplay/crypto-commons/commons-hub tenant set) |

> Each tenant is an independent stack with its own DB password, app
> signing secret, and (for postiz) third-party social tokens. Rotation
> is **per-tenant, staggered** — never big-bang all tenants at once
> (one breakage shouldn't take the whole fleet down).

## Procedure (repeat per tenant)

### 1. Inventory the live vs stopped tenants
```bash
ssh netcup-full 'docker ps --format "{{.Names}}" | grep -E "twenty|postiz|listmonk"'
```
Rotate only running tenants. Note stopped ones in the entry's `notes:`
(per Netcup memory several twenty-*/postiz-* are intentionally stopped).

### 2. Per tenant, classify its .env keys
Same triage as `runbook-multi-secret-env.md`:
- DB password → Postgres pattern + consumer check (split-config trap:
  twenty uses `PG_DATABASE_PASSWORD`+`APP_SECRET`; verify app/db share
  the var before treating as a simple swap).
- `APP_SECRET` / JWT → `openssl rand -hex 32`, restart, **all tenant
  sessions invalidated** — communicate per tenant.
- postiz social tokens (Twitter/X, BlueSky, LinkedIn, Mastodon…) →
  each is an external OAuth/app token; re-issue in that provider's
  portal, per `runbook-external-api-key.md`. These EXPIRE independently
  of our cadence — a 401 in postiz logs is the real trigger.
- SMTP → `runbook-mailcow-mailbox.md`.

### 3. Stagger
Rotate tenant A → verify (app health + logs clean) → wait → tenant B.
For twenty/postiz that's a `docker compose up -d --force-recreate` per
tenant dir and a health check before moving on.

### 4. Record once all targeted tenants are done
```bash
cd ~/Github/dev-ops && ./security/mark-rotated.sh <entry>
git add security/secrets-inventory.yaml && git commit -m "security: rotate <entry>"
```

## If something goes wrong
- **One tenant breaks** → its backup `.env.bak.*` + revert just that
  tenant; the others are untouched because you staggered.
- **postiz social token rejected** → that platform rotated/expired it
  server-side; re-link the account in postiz's UI, not just the .env.
- **DB auth failures** → split-config trap; restore .env.bak, ALTER
  back, lockstep (memory `postgres_rotation_consumer_verification`).

## Cross-references
`runbook-multi-secret-env.md`, `runbook-external-api-key.md`,
`runbook-listmonk-postgres.md`, `postgres-profiles/README.md`.
