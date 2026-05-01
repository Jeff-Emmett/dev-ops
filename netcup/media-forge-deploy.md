# media-forge deploy notes

Canonical repo: `gitea.jeffemmett.com/jeffemmett/media-forge` (public).
Public service: `https://media.jeffemmett.com`.
**Scale-to-zero**: idle 15m → container stops. Next request waits ~10–15s for cold-start, then fulfilled inline (Sablier blocking middleware).

## Deploy path on Netcup

`/opt/services/media-forge/` (matches doc-forge / image-forge / payment-forge sibling layout).

```bash
ssh netcup-full
cd /opt/services
git clone ssh://git@gitea.jeffemmett.com:223/jeffemmett/media-forge.git
cd media-forge
docker compose build         # ~5 min (ffmpeg + yt-dlp + gifski + scenedetect)
docker compose up -d
```

`.env` shape (optional — only if you want Infisical secret injection):

```bash
INFISICAL_PROJECT_SLUG=media-forge
INFISICAL_ENV=prod
# INFISICAL_CLIENT_ID=<fill in once project provisioned>
# INFISICAL_CLIENT_SECRET=<fill in once project provisioned>
```

The Infisical wrapper at `/opt/infisical/entrypoint-wrapper.sh`
(volume-mounted) gracefully no-ops when CLIENT_ID/SECRET aren't
set — the forge boots fully functional with whisper proxy + yt-dlp
(direct egress, no WG tunnel) until WG migration lands.

## Sablier scale-to-zero wiring

Three pieces, sourced from three different places:

### 1. Container labels (in `docker-compose.yml`)

```yaml
labels:
  - "sablier.enable=true"
  - "sablier.group=media-forge"
  - "traefik.enable=false"   # IMPORTANT: route lives in file provider
```

**Why `traefik.enable=false`**: when the container is stopped, Traefik's
docker provider drops the route, so the next inbound request 404s before
Sablier can intercept and wake. The fix is to register the route via
Traefik's file provider (which keeps routes regardless of container state).

### 2. Traefik file-provider config

Path on Netcup: `/root/traefik/config/sablier-media-forge.yml`. Repo
copy: [`netcup/traefik/dynamic/sablier-media-forge.yml`](traefik/dynamic/sablier-media-forge.yml).

```yaml
http:
  middlewares:
    sablier-media-forge:
      plugin:
        sablier:
          sablierUrl: http://sablier:10000
          group: media-forge
          sessionDuration: 15m
          blocking:
            timeout: 60s
  routers:
    media-forge:
      rule: "Host(`media.jeffemmett.com`)"
      entryPoints: [web]
      middlewares: [sablier-media-forge]
      service: media-forge
      priority: 100
  services:
    media-forge:
      loadBalancer:
        servers:
          - url: "http://media-forge:8000"
```

Traefik picks this up automatically (file provider has `watch=true`).
No restart needed.

**Blocking mode** chosen because media-forge is an HTTP API: callers wait
for the response inline rather than seeing a loading screen. Compare the
wizarr setup which uses `dynamic` mode (browser-rendered loading
screen) for an interactive UI.

### 3. Sablier discovers the container

The Sablier container at `/opt/sablier/` (image: `sablierapp/sablier:1.11.1`,
running on `traefik-public` + `rspace-internal`) auto-discovers any
container with `sablier.enable=true`. On boot you'll see in
`docker logs sablier`:

```
set groups ... new=...media-forge: [media-forge]...
```

That's the readiness signal — Sablier is now able to wake / sleep
this group on demand from the Traefik middleware.

## Cloudflare tunnel ingress

Same pattern as payment-forge — see `payment-forge-deploy.md` for the
full recipe. Two-step:

1. `cloudflared tunnel route dns <tunnel-id> media.jeffemmett.com`
   (creates the CNAME)
2. PUT `/cfd_tunnel/<tunnel-id>/configurations` to add the ingress
   entry routing `media.jeffemmett.com` → `http://localhost:80`
   (Traefik's web entrypoint).

Both steps are mandatory — the CNAME alone returns 404 until the
ingress entry lands.

## Smoke + wake tests

```bash
# while container is UP
curl -fsS https://media.jeffemmett.com/health

# stop the container, then send a request
ssh netcup-full "docker stop media-forge"
time curl -fsS https://media.jeffemmett.com/health
# Expect ~10–15s on the first call (Sablier wake), then status:ok
ssh netcup-full "docker ps --filter name=media-forge"
# Container should be Up again
```

## Uptime Kuma monitor

Monitor id 227, `media.jeffemmett.com — media-forge (Sablier)`:
- type: keyword
- url: `https://media.jeffemmett.com/health`
- keyword: `"status":"ok"`
- interval: 300s (5 min — gives the container time to sleep between checks)
- retries: 3, retryInterval: 60s
- notification: Mailcow (id=1)

The 5-minute interval is intentional: a 60s interval would keep the
container constantly awake, defeating the purpose of scale-to-zero.
With 5-minute checks + 15-minute idle TTL, the container sleeps
between Kuma probes, and wake takes ~10s (well under retryInterval),
so the Kuma view stays green.

Programmatic add via the kuma-alert-agent container (same recipe as
payment-forge — see `task-71` AC #15 closeout in dev-ops backlog).
**Use `MonitorType.KEYWORD` (not HTTP)** if you want the body-keyword
check applied — kuma silently drops the keyword arg on plain HTTP
monitors.

## Resource footprint

When awake: ~250 MB resident, 0.05 CPU at idle. Spikes to whatever
ffmpeg/yt-dlp/scenedetect needs during requests; bounded by
`MAX_UPLOAD_BYTES=500MB` per request and tmpfs `work-tmp` size limit
of 2 GB.

When asleep: 0 CPU, 0 RAM (container fully stopped). Sablier itself
consumes ~30 MB and stays running.

For the Netcup container limit enforcer (`/opt/scripts/enforce-
container-limits.sh`): media-forge inherits the default 256m/0.5cpu
cap unless explicitly overridden. The default is fine for
`/health`, `/formats`, `/scenedetect`, and small `/thumbnail` calls.
For heavy `/clip` or `/yt-dlp` calls, raise via `mem_limit:` in
docker-compose.yml — but note that the enforcer cron clobbers
`mem_limit` every 5 minutes, so the durable fix lives in the
enforcer's allowlist (see `netcup/scripts/enforce-container-limits.sh`).

## clip-forge migration plan

(Slice 2 of TASK-70 — operator session)

1. Replace inline `ffmpeg` / `yt-dlp` / `whisper` subprocess calls in
   `clip-forge/backend/app/services/` with HTTP calls to
   `https://media.jeffemmett.com`.
2. AI-highlight policy stays in clip-forge.
3. Migrate the WireGuard-tunneled SOCKS5 from clip-forge → media-
   forge (set `HTTP_PROXY` env var on the media-forge container).
4. arq worker queue stays in clip-forge (orchestrates media-forge
   calls).
5. User-facing API unchanged.

The intermediate state (clip-forge calls media-forge over HTTP for
some verbs while keeping inline copies as fallback) is fine while
the migration lands.
