# clip-forge — internal-routing patch (queued, NOT applied)

**Status:** patch staged in `docker-compose.yml`. Not yet applied to Netcup.
Apply only AFTER `rspace-online/feat/forge-integration-audit` lands on `main` and the rspace deploy is live.

## Why this patch exists

clip-forge today is reachable two ways:

| Path | Auth |
|---|---|
| `https://rspace.online/api/forges/clip-forge/*` | rspace `requireAuth()` (JWT or ZK-PKI) |
| `https://clip.jeffemmett.com/*` | Cloudflare Access (interactive login) |

The CF Access wall is the only thing standing between the public internet and clip-forge's `/yt-dlp` endpoint, which takes an arbitrary URL and triggers the yt-dlp + Whisper + Gemini pipeline (SSRF + cost amplification vector).

The rspace branch `feat/forge-integration-audit` adds three orthogonal defences to the proxy path:

1. Per-DID rate limit (12 req/min, burst 5 for clip-forge)
2. SSRF pre-filter on `/yt-dlp` (refuses loopback / RFC1918 / link-local / non-HTTP(S) URLs)
3. Conversion audit log at `/holonic/morpheus/log`

Once those land, the rspace path is sufficient on its own. CF Access becomes redundant — and the simpler model is to remove the public Traefik route entirely and rely on rspace as the only entry. This patch does that.

## Deploy ordering (REQUIRED)

```
1. rspace-online: feat/forge-integration-audit → dev → main → deploy
2. Verify the new defences live:
     curl -fsS https://rspace.online/holonic/tools | grep service-token
     # (and /holonic/morpheus/log should render)
3. Apply this patch (see "Apply procedure" below)
```

Doing #3 before #1 strips the CF Access wall WITHOUT the rspace defences in place — net regression. Don't.

## Apply procedure

```bash
# Push the patched compose:
scp netcup/clip-forge/docker-compose.yml \
    netcup-full:/opt/clip-forge/docker-compose.yml
ssh netcup-full \
    "cd /opt/clip-forge && docker compose up -d backend frontend"

# Wire rspace-online to use the internal hostname:
ssh netcup-full \
    "grep -q '^CLIP_FORGE_URL=' /opt/apps/rspace-online/.env || \
       echo 'CLIP_FORGE_URL=http://clip-forge:8000' >> /opt/apps/rspace-online/.env"
ssh netcup-full \
    "cd /opt/apps/rspace-online && docker compose up -d"

# Optional: remove the public Cloudflare route to avoid leaving a
# dangling DNS record that 502s. Either drop the DNS A/CNAME for
# clip.jeffemmett.com, OR remove the public-hostname entry from the
# Zero Trust tunnel config. See dev-ops/netcup/uptime-kuma/README.md
# for the tunnel API pattern.
```

## Verification

```bash
# Direct path is gone:
curl -sS -o /dev/null -w '%{http_code}' https://clip.jeffemmett.com/health
# expect: 502 (no Traefik route) or 530 (DNS removed)

# Proxied path still works (with rspace auth):
curl -fsS -H 'Authorization: Bearer <jwt>' \
  https://rspace.online/api/forges/clip-forge/health

# Internal path that rspace uses:
ssh netcup-full \
    "docker exec rspace-online curl -fsS http://clip-forge:8000/health"
# expect: 200 OK
```

## Diff vs current `/opt/clip-forge/docker-compose.yml`

```diff
@@ backend service ─────────────────────────────────────────────────
     labels:
-      - "traefik.enable=true"
-      - "traefik.http.routers.clipforge.rule=Host(`clip.jeffemmett.com`)"
-      - "traefik.http.services.clipforge.loadbalancer.server.port=8000"
+      # PUBLIC ROUTE REMOVED — proxied via rspace-online only.
+      - "traefik.enable=false"
     networks:
-      - default
-      - traefik-public
+      default: {}
+      traefik-public:
+        aliases:
+          - clip-forge
```

Everything else (postgres, redis, wireguard, worker, frontend) unchanged.

## Kuma monitor follow-up

Existing monitor **id 113 ClipForge** points at `https://clip.jeffemmett.com` — that URL will start returning 502 after this patch lands. To keep observability without re-exposing the public route:

```bash
# Replace the HTTP monitor with a Kuma push monitor fed from Netcup.
# Quick recipe (one-time, manual UI add):
#   1. Status page → Add Monitor → type "Push", name "clip-forge (internal probe)".
#   2. Copy the push token Kuma gives you.
#   3. Append it to /etc/uptime-kuma-push.env on Netcup as
#      CLIP_FORGE_PUSH_TOKEN=<token>.
#   4. Add a cron + bash one-liner that does:
#        docker exec uptime-kuma curl -fsS http://clip-forge:8000/health \
#          && curl -fsS -H 'Host: status.jeffemmett.com' \
#               http://127.0.0.1/api/push/$CLIP_FORGE_PUSH_TOKEN?status=up
```

Same shape as the existing `/opt/scripts/uptime-kuma-engine-pool-probe.sh` pattern. Defer this until the Kuma cutover; not blocking.

## Rollback

```bash
ssh netcup-full \
    "cd /opt/gitea-repos/clip-forge && git stash && \
     cp docker-compose.yml /opt/clip-forge/docker-compose.yml && \
     cd /opt/clip-forge && docker compose up -d backend frontend"
```

(Re-pulls the public-routed compose from the canonical Gitea repo.)
