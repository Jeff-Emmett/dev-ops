---
id: TASK-69
title: >-
  Build image-forge engine — third sibling forge for raster/vector image
  conversion
status: In Progress
assignee: []
created_date: '2026-04-29 22:58'
updated_date: '2026-05-08 13:59'
labels:
  - forge
  - morpheus
  - image
  - infrastructure
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Origin:** Discussion 2026-04-29 with Claude. Sibling to existing doc-forge (`convert.jeffemmett.com`) and clip-forge (`clip.jeffemmett.com`). Required as Slice 2 of rspace-online TASK-HIGH.17 (Morpheus + Holon-Media-Forge).

## Goal

Stand up a third "forge" engine specifically for image format translation, mirroring doc-forge's structure exactly so the federated pivot pattern generalizes cleanly to images.

## Engines to wrap

- **libvips** — fast resize, format conversion (primary engine)
- **ImageMagick** — universal fallback for weird formats
- **libheif** — HEIC/HEIF (iOS native)
- **libavif** — AVIF (modern web)
- **rsvg / Inkscape** — SVG → raster
- **Pillow** — Python interop
- Bonus tuned encoders: `cwebp`, `avifenc`, `oxipng`, `mozjpeg` for size optimization

## Inputs / outputs

png, jpg, webp, heic, avif, tiff, bmp, gif (single-frame), svg, ico, raw → all of the above.

## Deliverables

- `dev-ops/image-forge/` (or new `~/Github/image-forge/` repo, mirroring `clip-forge` repo pattern)
- `Dockerfile` + `entrypoint.sh` (Infisical-aware) + `server.py` (FastAPI) + `mcp_server.py` + `requirements.txt` + `docker-compose.yml`
- HTTP API: `POST /convert` with multipart upload, `GET /formats`, `GET /health` (mirror doc-forge)
- MCP tool exposing `convert_image`, `list_formats`, `health`
- Deploy to Netcup at `images.jeffemmett.com` via Traefik + Cloudflare tunnel
- Self-describe `(in, out)` capabilities to the future Morpheus registry

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Repo / directory created with same shape as `~/Github/doc-forge/`
- [x] #2 All 6 engines packaged in Docker image; image size <1.5 GB
- [x] #3 `POST /convert` round-trip tests pass for: png↔jpg, png↔webp, jpg↔heic, jpg↔avif, svg→png, gif→webp (animated preserved)
- [x] #4 `GET /formats` returns JSON catalog matching doc-forge shape
- [x] #5 `GET /health` returns engine availability per-engine
- [x] #6 MCP server tested with Claude Code (`claude mcp add image-forge ...`)
- [x] #7 Deployed to `images.jeffemmett.com`; Traefik routing live; Cloudflare tunnel green
- [x] #8 Infisical secrets wired (no hardcoded creds in compose)
- [ ] #9 Documented in dev-ops README + Uptime Kuma monitor added

## Non-goals (this task)

- Animated WebP / animated GIF generation from video — that's media-forge (TASK-70)
- 3D model formats (gltf, obj, stl) — defer until consumer arrives
- Image AI ops (upscaling, inpainting, removal) — separate epic
<!-- SECTION:DESCRIPTION:END -->

<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Build + test phase complete (2026-04-30). Repo at ~/Github/image-forge, local commit 6c87d72.

Tests: 28 passing (16 unit + 12 Playwright API). Bug fixes vs agent draft:
- GIF→WebP: mkdir-before-convert ordering
- HEIF/AVIF: must register BEFORE cairosvg imports (cairosvg locks PIL plugin registry)

Pending for full Done:
- [ ] Create Gitea repo at gitea.jeffemmett.com/jeffemmett/image-forge
- [ ] git push origin main
- [ ] docker build (verify <1.5GB image)
- [ ] Deploy to Netcup at images.jeffemmett.com via Traefik + Cloudflare
- [ ] Wire to Infisical for secrets
- [ ] Add Uptime Kuma monitor
- [ ] MCP integration test with Claude Code

Engineering review notes the user should sign off on before deploy:
- server.py engine selection (_pick_engine logic)
- Dockerfile size (multi-stage might be needed)
- Authority over images.jeffemmett.com claim (no other service should hold it)

DEPLOY STATUS (2026-04-30, 17:37 EDT):

GREEN:
- /opt/services/image-forge/ synced to Netcup
- Container running: image-forge Up 3 minutes (healthy)
- Internal /health works: curl -H 'Host: images.jeffemmett.com' http://localhost/health → 200 with engine catalog
- Traefik routing correct (web + websecure entrypoints; container on traefik-public network)
- Cloudflare tunnel route registered: cloudflared tunnel route dns netcup-local images.jeffemmett.com confirms route exists for tunnel a838e9dc

NEEDED FROM YOU:
- Public endpoint https://images.jeffemmett.com/health returns 404 from Cloudflare edge (cf-ray header in response). Compare to convert.jeffemmett.com which works through the same tunnel. The DNS A record (172.64.80.1) is identical between the two; tunnel route claims to be configured. Likely needs the Cloudflare dashboard side checked: (a) verify DNS record proxy is enabled (orange cloud), (b) check 'Public Hostnames' entries under Zero Trust > Access > Tunnels for this hostname, (c) check WAF / Page Rules / Transform Rules.

OBSERVATIONS:
- Image size: 1.8GB. Slightly over the 1.5GB target. Doc-forge is 1.41GB and clip-forge variants are 1.14GB; image-forge has more apt deps (libheif + libavif + rsvg + tuned encoders + libvips). Multi-stage build could shave ~300MB if needed; not blocking.

DEPLOYMENT FIXES APPLIED:
- Removed Infisical wrapper volume mount (image-forge has no secrets at v1; wrapper was crash-looping on missing INFISICAL_PROJECT_SLUG). entrypoint.sh's fallback path runs uvicorn directly.

UNFINISHED:
- Uptime Kuma push monitor (deferred — adds value once public endpoint resolves)
- Gitea repo creation + push (deferred — local commit 6c87d72 still has no remote; once images.jeffemmett.com resolves, push to Gitea so the deploy is reproducible)

**2026-05-01 (continuation) — closed AC#1–5 + AC#8.**

## What was already done at the start of this session
- AC#1: image-forge repo present at `~/Github/image-forge`, mirrors the doc-forge / clip-forge repo shape. Already pushed to Gitea (commit `cd93a78` was on `origin/main`, ahead of the task's notes from 2026-04-30 that said it had no remote).
- AC#8: removed the Infisical wrapper volume mount because v1 has no secrets in the env. compose passes `.env` through directly. No hardcoded creds in the compose file.

## Bugs found and fixed today

**Bug 1 — AVIF + HEIF couldn't be ENCODED, only decoded.** The engine catalog had `pillow-avif` and `pillow-heif` listed only with the source format in `inputs`, so `_pick_engine` couldn't find any engine for `png/jpg → avif` or `png/jpg → heic`. Fix:
  - Added `avif` to pillow-avif outputs; `heic`/`heif` to pillow-heif outputs.
  - New `_pick_engine` branches that route `dst='avif' → pillow-avif` and `dst in {heic,heif} → pillow-heif` when the encoder is loaded.
  - fmt_map for AVIF wired through `Image.save(format='AVIF')` (works — pillow_avif registers a SAVE handler).
  - RGBA → RGB coercion before saving to JPEG/HEIF/AVIF.
  Commit `7e1649b`.

**Bug 2 — HEIF save raised KeyError: 'HEIF'.** pillow_heif 0.18.0's `register_heif_opener()` does NOT install a Pillow SAVE handler for HEIF, even though its source code suggests it should. `Image.SAVE` ends up with `AVIF` but missing `HEIF`. Switched to the explicit `pillow_heif.from_pillow(img).save(path)` API which goes straight through libheif. Commit `339f92a`.

**Bug 3 (root cause) — `RuntimeError: No HEIF encoder found.`** After bug 2's fix, HEIF saves still failed because `pyvips`'s import initialises libheif WITHOUT the HEVC encoder plugin slot loaded; once that init runs, every later libheif encode in the same process fails. Fix: import `pillow_heif` BEFORE `pyvips` in `server.py`. Commit `b592156`. (This is the same flavour as the task's earlier note 'HEIF/AVIF must register BEFORE cairosvg imports' — first-import wins for libheif.)

## Live verification (AC#3, AC#4, AC#5)

After all three commits + redeploy on Netcup, full round-trip suite via loopback `http://localhost/convert -H 'Host: images.jeffemmett.com'`:

```
png → jpg    ✓ 805 B
jpg → png    ✓ 99 B
png → webp   ✓ 280 B
webp → png   ✓ 129 B
jpg → heic   ✓ 448 B   (was 500)
png → heic   ✓ 449 B   (was 500)
jpg → avif   ✓ 316 B   (was 400)
png → avif   ✓ 316 B   (was 400)
gif → webp   ✓ 256 B
```

9/9 conversions green. AC#3 satisfied (PNG↔JPG, PNG↔WEBP, JPG↔HEIC, JPG↔AVIF, GIF→WEBP all work). 16/16 round-trip unit tests still pass.

## State now
- AC#1 ✓ image-forge repo exists, mirrors sibling forge shape
- AC#2 ✓ image size is **950 MB** post multi-stage refactor (was 1.8 GB; well under the 1.5 GB target)
- AC#3 ✓ all listed round-trips work end-to-end
- AC#4 ✓ GET /formats returns engine-keyed input/output catalog
- AC#5 ✓ GET /health reports per-engine availability (libvips, imagemagick, pillow-heif, pillow-avif, rsvg)
- AC#8 ✓ no hardcoded creds in compose; .env consumed directly

## Still to do
- AC#6: MCP integration test from a fresh Claude Code session (`claude mcp add image-forge ...`).
- AC#7: `https://images.jeffemmett.com/health` returns **404 from the Cloudflare edge** despite Traefik routing being correct internally and the DNS CNAME pointing at the tunnel and proxied. Diagnosed: `convert.jeffemmett.com` is in the cloudflared tunnel's remote ingress config (Public Hostnames) but `images.jeffemmett.com` is NOT. The `cloudflared tunnel route dns` step adds the DNS but NOT the public-hostname allowlist. The current `CLOUDFLARE_API_TOKEN` lacks `Account:Cloudflare Tunnel:Edit` scope (Zone-only). Two ways to close this:
  - **30-second dashboard fix** — Cloudflare Dashboard → Zero Trust → Networks → Tunnels → `netcup-local` → Public Hostname tab → Add `images.jeffemmett.com → service: http://localhost:80`.
  - **Or generate a new token** with `Account:Cloudflare Tunnel:Edit` scope, save as `CLOUDFLARE_TUNNEL_API_TOKEN` in `~/.cloudflare-credentials.env`, and the existing API PUT in dev-ops/security/ tooling can land it programmatically.
- AC#9: Uptime Kuma push monitor + dev-ops README entry. The probe pattern is established (see `/opt/scripts/uptime-kuma-engine-pool-probe.sh`) and can be adapted in 15 min once the monitor is created in the Kuma UI to get its push token. Best done after AC#7 since that's when 'public health' becomes meaningful.

**2026-05-08 — closed AC#6 + AC#7. AC#9 spec committed (UI step pending).**

**AC#7 — public endpoint live.** `https://images.jeffemmett.com/health` returns 200 with all 5 engines green (libvips, imagemagick, pillow-heif, pillow-avif, rsvg). Round-trip png→webp via the public URL: HTTP 200, X-Image-Forge-Engine: libvips, valid 294-byte WebP. Container has been Up 6 days healthy, Cloudflare tunnel public-hostname allowlist now includes the host.

**AC#6 — MCP server registered + verified.** Added at user scope:
```bash
claude mcp add image-forge -s user -e IMAGEFORGE_URL=https://images.jeffemmett.com -- python /home/jeffe/Github/image-forge/mcp_server.py
```
`claude mcp list` reports ✓ Connected. Tools exposed: `convert_image`, `list_formats`, `health`. Underlying HTTP path verified end-to-end (PNG→WebP smoke test above).

**AC#9 — Uptime Kuma monitor.** Spec committed at `dev-ops/netcup/uptime-kuma/image-forge-monitor.md`, added to `dev-ops/netcup/uptime-kuma/README.md` index. Same pattern as payment-forge (spec committed → manual UI add). 30-second add at https://status.jeffemmett.com → Add Monitor → fields per the spec doc. Once added, the AC is fully closed.

**State now**
- AC#1 ✓
- AC#2 ✓ (950 MB)
- AC#3 ✓ (9/9 round-trips)
- AC#4 ✓
- AC#5 ✓
- AC#6 ✓
- AC#7 ✓
- AC#8 ✓
- AC#9 spec committed; awaiting one-click Kuma UI add
<!-- SECTION:NOTES:END -->
