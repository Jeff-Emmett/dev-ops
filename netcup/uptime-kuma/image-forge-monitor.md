# Uptime Kuma monitor — image-forge

Manual UI add at https://status.jeffemmett.com → Settings → Monitors → Add New Monitor.

## Monitor config

| Field | Value |
|-------|-------|
| Monitor Type | HTTP(s) |
| Friendly Name | `images.jeffemmett.com — image-forge` |
| URL | `https://images.jeffemmett.com/health` |
| Heartbeat Interval | `60` (seconds) |
| Retries | `3` |
| Heartbeat Retry Interval | `30` |
| Request Method | `GET` |
| Accepted Status Codes | `200-299` |
| Body Keyword (optional) | `"status":"ok"` |
| Tags | `forge`, `images` |
| Notifications | ☑ Mailcow Email Alerts (id=1) |

`/health` returns per-engine availability:

```json
{"status":"ok","engines":{"libvips":true,"imagemagick":true,"pillow-heif":true,"pillow-avif":true,"rsvg":true}}
```

The `"status":"ok"` body keyword confirms the FastAPI process is up; per-engine flags ride along for human inspection on the monitor's heartbeat detail view. Engine-by-engine alerting is intentionally not split out — if any one engine flips false the whole image fails Definition-of-Done and a single composite alert is the right call.

## Why HTTP, not push

Same rationale as `payment-forge-monitor.md` — image-forge is on `traefik-public` and the public URL exercises Cloudflare tunnel + DNS + Traefik + container health in one check.

## After adding

```bash
ssh netcup "docker logs image-forge --tail 30"
ssh netcup "curl -fsS -H 'Host: images.jeffemmett.com' http://localhost/health"
curl -fsS https://images.jeffemmett.com/health
```

If the third fails alone, the tunnel public-hostname allowlist is missing `images.jeffemmett.com` — add via Cloudflare Dashboard → Zero Trust → Networks → Tunnels → `netcup-local` → Public Hostnames, or the API path documented in this directory's `README.md`.
