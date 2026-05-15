# Runbook: rotate a Directus instance's admin/DB secrets (shared pattern)

**Applies to** these inventory entries (`mode: manual`):

| Inventory entry | Instance | .env / consumer |
|---|---|---|
| `commons-hub-directus-password` | Commons Hub Directus | `~/.secrets/private/commons_hub_directus_password` + the instance .env |
| `commons-hub-directus-app-secrets` | Commons Hub Directus | `/opt/apps/commons-hub-directus/.env` (KEY, SECRET, DB pw, admin email/pw, SMTP) |
| `directus-fritsch-password` | Fritsch Directus | `~/.secrets/private/directus_fritsch_password` + the instance .env |

> Directus has several distinct secrets per instance; rotate the ones
> that apply. They differ in blast radius:
> - **`KEY` / `SECRET`** — sign/encrypt tokens + sessions. Rotating
>   invalidates all active sessions + any cached access tokens. Schedule
>   it; expect every logged-in user to re-auth.
> - **DB password** — Postgres role. SPLIT-CONFIG RISK: if the app reads
>   the DB pw from a different source than the postgres container's
>   `POSTGRES_PASSWORD`, see the listmonk lesson
>   (`postgres_rotation_consumer_verification` memory) — verify same
>   `${VAR}` before treating it as a simple swap.
> - **Admin password** — the bootstrap admin user. Rotate via the
>   Directus UI (Users → admin) OR `npx directus users passwd`.
> - **SMTP password** — see `runbook-mailcow-mailbox.md` if it's a
>   Mailcow mailbox.

## Steps (per secret you're rotating)

### Admin password
```bash
ssh netcup-full 'docker exec <directus-container> npx directus users passwd \
  --email <admin-email> --password "<NEW>"'
# update the canonical ~/.secrets/private/ file + any consumer .env
```

### KEY / SECRET (token-signing)
```bash
NEW_KEY=$(openssl rand -hex 32); NEW_SECRET=$(openssl rand -hex 32)
ssh netcup-full "cp <env> <env>.bak.\$(date -u +%Y%m%d-%H%M%S) && \
  sed -i 's|^KEY=.*|KEY=$NEW_KEY|; s|^SECRET=.*|SECRET=$NEW_SECRET|' <env>"
ssh netcup-full 'cd <dir> && docker compose up -d --force-recreate <directus>'
# Expect: all users logged out — communicate beforehand.
```

### DB password
Follow the Postgres pattern with the consumer check from
`postgres-profiles/README.md`. If app + postgres share the same
`${VAR}` it's a generic rotation; if not, lockstep both like
`runbook-listmonk-postgres.md`.

## Smoke test
```bash
curl -sf https://<directus-host>/server/health | jq .status   # → "ok"
# Admin login still works (UI), and a known API token call 200s.
ssh netcup 'docker logs --since 60s <directus-container> | grep -iE "error|auth|password"'
```

## Record
```bash
cd ~/Github/dev-ops && ./security/mark-rotated.sh <entry>
git add security/secrets-inventory.yaml && git commit -m "security: rotate <entry>"
```

## If something goes wrong
- **All API integrations 401 after KEY/SECRET rotation** — expected for
  cached tokens; clients re-auth. Static API tokens stored in Directus
  survive (they're DB rows, not KEY-derived) — verify those still work.
- **DB auth failures post-rotation** — the split-config trap. Restore
  `<env>.bak`, ALTER USER back, recreate. Then do the lockstep version.

## Cross-references
`runbook-listmonk-postgres.md` (split-config postgres),
`runbook-mailcow-mailbox.md` (SMTP), memory
`postgres_rotation_consumer_verification`.
