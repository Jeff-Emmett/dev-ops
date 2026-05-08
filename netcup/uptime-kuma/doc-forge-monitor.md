# Uptime Kuma monitor — doc-forge

Spec for the keyword monitor on doc-forge's public health endpoint. Useful as a recreate reference if the monitor is ever lost or rebuilt elsewhere.

## Monitor config

| Field | Value |
|-------|-------|
| Monitor Type | HTTP(s) — Keyword |
| Friendly Name | `convert.jeffemmett.com — doc-forge` |
| URL | `https://convert.jeffemmett.com/health` |
| Heartbeat Interval | `60` (seconds) |
| Retries | `3` |
| Heartbeat Retry Interval | `30` |
| Request Method | `GET` |
| Accepted Status Codes | `200-299` |
| Body Keyword | `"status":"ok"` |
| Tags | `forge`, `documents` |
| Notifications | ☑ Mailcow Email Alerts (id=1) |

`/health` returns:

```json
{
  "status": "ok",
  "engines": [
    "libreoffice", "tectonic", "typst", "pandoc",
    "scribus", "inkscape", "graphviz",
    "plantuml", "mermaid", "vips"
  ],
  "unoserver": "available"
}
```

The body keyword check on `"status":"ok"` confirms the FastAPI process is up *and* unoserver is reachable (doc-forge sets status=ok only when both are healthy).

## Why HTTP, not push

Same rationale as `payment-forge-monitor.md` and `image-forge-monitor.md` — doc-forge is on `traefik-public` and the public URL exercises Cloudflare tunnel + DNS + Traefik + container health in one check.

## After adding

```bash
ssh netcup "docker logs doc-forge --tail 30"
ssh netcup "curl -fsS -H 'Host: convert.jeffemmett.com' http://localhost/health"
curl -fsS https://convert.jeffemmett.com/health
```
