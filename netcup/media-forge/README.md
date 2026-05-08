# media-forge — internal-routing patch (queued, NOT applied)

**Status:** patch staged — disable the Sablier-fronted public route by renaming the Traefik file-provider config to `.disabled`. Not yet applied.
Apply only AFTER `rspace-online/feat/forge-integration-audit` lands on `main` and the rspace deploy is live.

## Why this patch exists

media-forge has the same `/yt-dlp` SSRF + cost-amplification surface as clip-forge (both shell out to yt-dlp + reach Whisper for transcription). Today `media.jeffemmett.com` is publicly routable — Traefik file provider serves the route, Sablier scales the container to zero between requests. There's no Cloudflare Access on it. The only protection against anonymous abuse of `/yt-dlp` is the rate of cold-start delays and obscurity.

The rspace branch `feat/forge-integration-audit` adds three orthogonal defences to the proxy path:

1. Per-DID rate limit (12 req/min, burst 5 for media-forge — same as clip-forge)
2. SSRF pre-filter on `/yt-dlp`
3. Conversion audit log

Once those land, the rspace path is sufficient. We pull media-forge off the public route entirely; rspace becomes the only entry. The Sablier scale-to-zero pattern is preserved — just no public hostname.

## Deploy ordering (REQUIRED)

```
1. rspace-online: feat/forge-integration-audit → dev → main → deploy
2. Verify the new defences live (rspace.online/holonic/tools)
3. Apply this patch (see "Apply procedure")
```

Doing #3 before #1 means anonymous internet can hit `/yt-dlp` until the rspace defences are live. Today that risk is partially masked by the cold-start delay; don't worsen it.

## Apply procedure

```bash
# Disable the file-provider route. Traefik watches for *.yml only;
# the .disabled extension means it stops serving the route on next
# reload (file provider is hot-reloaded — no Traefik restart needed).
ssh netcup-full \
    "mv /root/traefik/config/sablier-media-forge.yml \
        /root/traefik/config/sablier-media-forge.yml.disabled"

# Wire rspace-online to use the internal hostname (already on
# rspace-internal + traefik-public networks; aliases preserved).
ssh netcup-full \
    "grep -q '^MEDIA_FORGE_URL=' /opt/apps/rspace-online/.env || \
       echo 'MEDIA_FORGE_URL=http://media-forge:8000' >> /opt/apps/rspace-online/.env"
ssh netcup-full \
    "cd /opt/apps/rspace-online && docker compose up -d"

# Verify Traefik dropped the route:
curl -sS -o /dev/null -w '%{http_code}' https://media.jeffemmett.com/health
# expect: 404 (Traefik no longer routes Host: media.jeffemmett.com)

# Optional: remove the public-hostname allowlist + DNS record for
# media.jeffemmett.com in Cloudflare. Leaves no dangling external entry.
```

## Verification

```bash
# Public path is gone:
curl -sS -o /dev/null -w '%{http_code}' https://media.jeffemmett.com/health
# expect: 404 (no Traefik route) or 530 (DNS removed)

# Proxied path still works (with rspace auth):
curl -fsS -H 'Authorization: Bearer <jwt>' \
  https://rspace.online/api/forges/media-forge/health

# Internal path that rspace uses:
ssh netcup-full \
    "docker exec rspace-online curl -fsS http://media-forge:8000/health"
# expect: 200 OK with binaries+integrations
```

## Sablier scale-to-zero — keep working?

Yes — the Sablier middleware was attached to the public router. Now that the public router is gone, Sablier won't trigger wake-up on incoming traffic. We have two options:

| Option | Sablier behaviour | Recommendation |
|---|---|---|
| Leave Sablier alone, container stays running | always-on, ~600 MB RAM | simpler; OK while load is light |
| Wire Sablier to the rspace-internal traffic too | container scales to zero, rspace proxy waits for cold-start on first call after idle | needs a new file-provider entry that watches a fake-internal hostname; not worth the complexity for now |

Recommend **option 1** for the cutover. Manually `docker stop media-forge` if you want to free the RAM during quiet periods; `docker start media-forge` brings it back. A future Sablier-aware proxy hop in rspace could automate this — out of scope here.

## Kuma monitor follow-up

Existing monitor **id 227 media-forge (Sablier)** points at `https://media.jeffemmett.com/health` — that URL will start returning 404 after this patch lands. Replace with a Kuma push monitor fed from Netcup, same shape as documented in `dev-ops/netcup/clip-forge/README.md`. Token name: `MEDIA_FORGE_PUSH_TOKEN`.

## Rollback

```bash
ssh netcup-full \
    "mv /root/traefik/config/sablier-media-forge.yml.disabled \
        /root/traefik/config/sablier-media-forge.yml"
# Traefik re-picks up the route automatically (file provider hot-reload).
# Optional: drop MEDIA_FORGE_URL from rspace .env if you want rspace
# to use the public hostname again.
```

## Reference: the disabled config

The committed `sablier-media-forge.yml.disabled` mirrors what currently lives at `/root/traefik/config/sablier-media-forge.yml` on Netcup, so the apply procedure is "rename, replace contents only if drift is intentional".
