# Uptime Kuma

Status page at https://status.jeffemmett.com (Cloudflare Access protected).

**Deploy location**: `/opt/apps/uptime-kuma/` on Netcup.
**Data**: persisted in named Docker volume `uptime-kuma_uptime-kuma-data` (sqlite at `/app/data/kuma.db`).
**TLS**: terminated at Cloudflare edge — origin runs HTTP only via `traefik-public` (`web` entrypoint).

## Sync this compose to the server

```bash
scp docker-compose.yml netcup:/opt/apps/uptime-kuma/docker-compose.yml
ssh netcup 'cd /opt/apps/uptime-kuma && docker compose up -d'
```

## Coverage

174 active monitors as of 2026-04-27 — public HTTPS endpoints, Mailcow IMAP/SMTP port checks, daily DB backup push monitor. All wired to the "Mailcow Email Alerts" notification channel.

Monitor specs that need a manual UI add (committed for reproducibility):

- `pay.jeffemmett.com` — payment-forge — see `payment-forge-monitor.md`

## Internal-network monitor reachability (from `traefik-public`)

| Target                     | Reachable | How                                         |
|----------------------------|-----------|---------------------------------------------|
| `http://litellm:4000`      | ✅        | container DNS on `traefik-public`           |
| `http://infisical:8080`    | ✅        | container DNS on `traefik-public`           |
| Ollama on host (`:11434`)  | ❌        | host gateway blocked from this bridge net   |

For host-service monitors (Ollama, host-level systemd units), use a **push monitor** with a cron on Netcup that `curl`s the health endpoint and pings Kuma's push URL on success.
