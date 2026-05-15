# Runbook: rotate Uptime Kuma credentials (shared)

**Applies to**:

| Inventory entry | Secret |
|---|---|
| `kuma-admin-password` | Kuma admin login (`jeffemmett`) — ALSO drives kuma-alert-agent's Socket.IO API. Source of truth = Infisical. |
| `kuma-api-key` | Kuma v1.x API key (`~/.secrets/private/kuma_api_key`) — badge/metrics/Prometheus only; NOT monitor CRUD. |

> Order matters for the admin password: the kuma-alert-agent
> authenticates with it via Socket.IO. Change it in the wrong order and
> the agent loses access until both sides realign.

## kuma-admin-password

1. **Kuma UI first** (<https://status.jeffemmett.com>, behind CF Access):
   Settings → Account → change password to a new value. (No API for
   self-password-change in Kuma 1.x — UI only.)
2. **Then Infisical**: update `KUMA_PASSWORD` in the kuma-alert-agent
   project (the agent reads it via the Infisical entrypoint at startup —
   it's NOT in a plain .env; see memory `kuma_admin_api_via_agent`).
3. **Restart the agent** so it re-auths:
   ```bash
   ssh netcup-full 'docker restart kuma-alert-agent'
   ```
4. Smoke test — the agent reconnected:
   ```bash
   ssh netcup 'docker logs --since 60s kuma-alert-agent 2>&1 \
     | grep -iE "login|socket|auth|connected|error"'
   ```
   It should log a successful Kuma login, not an auth error.
   (Cross-check: the agent can still see monitors — it polls them.)
5. `./security/mark-rotated.sh kuma-admin-password` + commit.

**Recovery**: if the agent can't auth, the UI password and Infisical
value disagree. Re-set them to the same value (UI is fastest to read
back via a fresh login), restart the agent.

## kuma-api-key

Low blast — badges/metrics only.
1. Kuma UI → Settings → API Keys → revoke the old, create a new one.
2. `f=~/.secrets/private/kuma_api_key; cp "$f" "$f.bak.$(date -u +%Y%m%d-%H%M%S)"; printf '%s' "<NEW>" > "$f"`
3. Update any consumer (Prometheus scrape config / badge URLs — audit:
   nothing scripted consumes it as of 2026-05-15, so usually just the
   file).
4. Smoke: `curl -H "Authorization: Bearer <NEW>" https://status.jeffemmett.com/metrics | head` (via CF Access) or the loopback Host-header trick used by the push monitors.
5. `./security/mark-rotated.sh kuma-api-key` + commit.

## Cross-references
Memory `kuma_admin_api_via_agent` (how the agent gets KUMA_PASSWORD from
/proc/1/environ — relevant if you ever script Kuma monitor CRUD),
`runbook-infisical-service-token.md` (the Infisical side).
