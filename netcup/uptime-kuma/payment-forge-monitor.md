# Uptime Kuma monitor — payment-forge

Manual UI add at https://status.jeffemmett.com → Settings → Monitors → Add New Monitor.

## Monitor config

| Field | Value |
|-------|-------|
| Monitor Type | HTTP(s) |
| Friendly Name | `pay.jeffemmett.com — payment-forge` |
| URL | `https://pay.jeffemmett.com/health` |
| Heartbeat Interval | `60` (seconds) |
| Retries | `3` |
| Heartbeat Retry Interval | `30` |
| Request Method | `GET` |
| Accepted Status Codes | `200-299` |
| Body Keyword (optional) | `"status":"ok"` |
| Tags | `forge`, `payments` |
| Notifications | ☑ Mailcow Email Alerts (id=1) |

The `/health` endpoint returns rail availability — body keyword check on `"status":"ok"` confirms not just HTTP 200 but that the rail registry is populated.

## Why HTTP, not push

The forge runs as a containerized HTTP service behind Traefik on the
`traefik-public` Docker network. Kuma is on the same network and can reach
`http://payment-forge:8000/health` directly OR via the public hostname. We
use the public URL so the monitor also exercises Cloudflare tunnel + DNS
+ Traefik routing — a single check covers the full ingress path.

## After adding

Confirm the monitor goes green within ~2 minutes. If it stays yellow/red:

```bash
ssh netcup "docker logs payment-forge --tail 30"
ssh netcup "curl -fsS -H 'Host: pay.jeffemmett.com' http://localhost/health"
curl -fsS https://pay.jeffemmett.com/health
```

The first two should always succeed once the container is up; if the third
fails alone, the issue is in the Cloudflare tunnel ingress config (managed
via Cloudflare API — see `dev-ops/netcup/uptime-kuma/README.md` for the
tunnel ingress addition pattern used in TASK-71).
