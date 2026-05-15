# Runbook: rotate an Infisical service token (shared pattern)

**Applies to**:

| Inventory entry | What it is |
|---|---|
| `infisical-funion-sidecar-client-secret` | One service's Universal-Auth client_id/secret pair |
| `infisical-service-tokens-multi-service` | The ~33-service fleet of bootstrap pairs (each `/opt/apps/<svc>/.env` with `INFISICAL_CLIENT_ID`+`INFISICAL_CLIENT_SECRET`) |

> These are the *bootstrap* credentials every Infisical-using container
> needs in plain `.env` to fetch the rest of its secrets at startup.
> Rotating one is per-service and low-blast (only that service); the
> fleet entry is a staged campaign, never big-bang.

## Single service

1. Infisical UI → the project → **Access Control → Identities** (or
   Service Tokens, depending on Infisical version) → the identity used
   by this service → **Universal Auth → Client Secrets** → "Add" a new
   secret, copy it. Don't delete the old one yet.
2. Update the service's `.env` on Netcup:
   ```bash
   ssh netcup-full "cp /opt/apps/<svc>/.env /opt/apps/<svc>/.env.bak.\$(date -u +%Y%m%d-%H%M%S) && \
     sed -i 's|^INFISICAL_CLIENT_SECRET=.*|INFISICAL_CLIENT_SECRET=<NEW>|' /opt/apps/<svc>/.env"
   ```
   (CLIENT_ID only changes if you created a whole new identity — usually
   you just roll the secret.)
3. Restart so the entrypoint re-auths:
   ```bash
   ssh netcup-full 'cd /opt/apps/<svc> && docker compose up -d'
   ```
4. **Smoke test = the entrypoint successfully fetched secrets.** Watch
   the container come up clean:
   ```bash
   ssh netcup 'docker logs --since 60s <svc> 2>&1 | grep -iE "infisical|secret|auth|started|listening|error"'
   ```
   A failed Infisical auth shows as the entrypoint erroring before the
   app starts — the container will crash-loop. That's the signal.
5. Revoke the OLD client secret in the Infisical UI.
6. `./security/mark-rotated.sh <entry>` + commit.

## Fleet (`infisical-service-tokens-multi-service`)

Same per service, **staggered**: roll one service's secret → confirm it
came up clean → next. Use `security/netcup-service-envs.md` (the
Infisical-using list) as the work queue. Don't script a fleet-wide
big-bang — one bad entrypoint shouldn't take 33 services down at once.

Rotate-on-suspicion, not on a hard cadence, is acceptable for these:
they're scoped per-service and the blast radius of one leaking is just
that service's secret set (still worth the 365d digest nudge).

## If something goes wrong
- **Container crash-loops after rotation** → entrypoint can't auth to
  Infisical. Restore `.env.bak`, `docker compose up -d`, re-check the
  new secret was copied correctly (no trailing newline/space).
- **Wrong identity rolled** → Infisical audit log shows which identity;
  create a fresh secret on the correct one.

## Cross-references
`runbook-external-api-key.md` (shape), `security/netcup-service-envs.md`
(the Infisical-using service list), `infisical-projects-audit` entry
(coverage review — see `runbook-audit-meta.md`).
