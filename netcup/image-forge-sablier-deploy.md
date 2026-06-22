# image-forge → Sablier scale-to-zero (migration runbook)

Canonical repo: `gitea.jeffemmett.com/jeffemmett/image-forge`.
Public service: `https://images.jeffemmett.com`.
Deploy path on Netcup: `/opt/services/image-forge/` (doc-forge / media-forge / payment-forge sibling layout).

This migrates an **already-live** service from docker-provider routing (always
warm) to **Sablier scale-to-zero** (idle 15m → stopped). It is the deploy step
for TASK-MEDIUM.17 AC#6, and it's what makes the heavy Inkscape engine safe on
a memory-pressured host: when idle, the whole container stops, so the ~1 GB
Inkscape image costs only disk, never resident RAM.

## What changed in the repo

- `docker-compose.yml` — replaced the docker-provider Traefik labels with the
  Sablier trio (`sablier.enable=true`, `sablier.group=image-forge`,
  `traefik.enable=false`); added `INKSCAPE_SHELL` / `INKSCAPE_IDLE_TIMEOUT`;
  bumped the memory limit to 1500M for vector-render headroom.
- `dev-ops/netcup/traefik/config/sablier-image-forge.yml` — the file-provider
  router + Sablier middleware (route survives container stop).

## Why the order matters

Two failure modes to avoid:
1. **File config present, but no container carries `sablier.enable` yet** →
   the Sablier middleware references group `image-forge` with zero members and
   can't wake anything → requests hang/timeout.
2. **Container recreated with `traefik.enable=false`, but file config absent**
   → no router for the host → 404.

So the container (with Sablier labels) and the file config must land together.
image-forge is request-driven, so a planned few-second blip is acceptable.

## Pre-flight

```bash
ssh netcup-full
docker ps --format '{{.Names}}' | grep -x sablier        # Sablier must be up
ls /etc/traefik/config/sablier-*.yml                      # file provider watched here
```

## Migrate

```bash
# 1. Drop the file-provider route in place (Traefik picks it up via watch).
#    Until step 3 recreates the container with sablier.enable, this router
#    points at a group with no managed member — so do 1→3 back-to-back.
scp netcup/traefik/config/sablier-image-forge.yml \
    netcup-full:/etc/traefik/config/sablier-image-forge.yml

# 2. Pull the new compose + build (first build pulls the Inkscape/GTK layer,
#    ~several hundred MB — allow time).
ssh netcup-full 'cd /opt/services/image-forge && git pull origin main \
    && docker compose build'

# 3. Recreate with the Sablier labels. Brief (~seconds) route blip here.
ssh netcup-full 'cd /opt/services/image-forge && docker compose up -d --force-recreate'
```

To build without the heavy engine (drops the route-able formats eps/ps/emf/dxf
and PDF→SVG import, keeps everything else):

```bash
docker compose build --build-arg WITH_INKSCAPE=0
```

## Verify

CF Bot Fight Mode 403s a bare `curl/x.y` UA — send a browser UA for external
probes (see vaultwarden note).

```bash
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'

# Cold wake: first hit after idle takes a few seconds, then 200.
curl -s -A "$UA" https://images.jeffemmett.com/health | jq
#   expect: {"status":"ok","engines":{...,"inkscape":true},"inkscape_mode":"shell"}

curl -s -A "$UA" https://images.jeffemmett.com/formats | jq '.engines | keys'
#   expect: [...,"inkscape",...]

# Vector interchange round-trips through the gated engine:
curl -s -A "$UA" -X POST https://images.jeffemmett.com/convert \
  -F file=@logo.svg -F to=eps -o /tmp/logo.eps && head -c 4 /tmp/logo.eps  # %!PS

curl -s -A "$UA" -X POST https://images.jeffemmett.com/convert \
  -F file=@diagram.pdf -F to=svg -o /tmp/diagram.svg && grep -c '<svg' /tmp/diagram.svg
```

## RAM behaviour (AC#6)

```bash
ssh netcup-full
# After a vector job, the Inkscape --shell is resident:
docker stats --no-stream image-forge
# Wait > INKSCAPE_IDLE_TIMEOUT (120s) with no vector jobs → reaper kills it,
# RSS drops back toward the uvicorn baseline:
docker stats --no-stream image-forge
# After 15m fully idle → Sablier stops the container entirely (0 RAM):
docker ps -a --filter name=image-forge --format '{{.Names}} {{.Status}}'   # Exited
```

Expected layering: **idle 15m → container Exited (0 RAM)**; **warm but no vector
job for 120s → Inkscape reaped (uvicorn baseline only)**; **active vector burst
→ Inkscape resident within the 1500M limit**.

## First-run gotcha — Inkscape action syntax

The `--shell` action chain uses Inkscape **1.x** names (`file-open`,
`export-type`, `export-filename`, `export-plain-svg`, `export-width`,
`export-do`, `file-close`). Confirm the deployed point release accepts them:

```bash
ssh netcup-full 'docker exec image-forge inkscape --version'
ssh netcup-full 'docker exec image-forge sh -c \
  "printf %s \"file-open:/tmp/t.svg; export-type:eps; export-filename:/tmp/t.eps; export-do; file-close\n\" | inkscape --shell"'
```

If a name differs, fix `_inkscape_actions()` in `server.py`. Setting
`INKSCAPE_SHELL=0` falls back to one-shot `inkscape --actions=…` per job
(same action names, no warm process) for debugging.

## Rollback

```bash
# Revert to always-warm docker-provider routing:
ssh netcup-full 'rm /etc/traefik/config/sablier-image-forge.yml'
ssh netcup-full 'cd /opt/services/image-forge && git checkout <pre-migration-sha> -- docker-compose.yml \
    && docker compose up -d --force-recreate'
```
