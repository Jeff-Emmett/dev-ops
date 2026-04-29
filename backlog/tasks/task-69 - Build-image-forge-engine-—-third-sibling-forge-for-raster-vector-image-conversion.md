---
id: TASK-69
title: >-
  Build image-forge engine — third sibling forge for raster/vector image
  conversion
status: To Do
assignee: []
created_date: '2026-04-29 22:58'
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

## Acceptance criteria

- [ ] Repo / directory created with same shape as `~/Github/doc-forge/`
- [ ] All 6 engines packaged in Docker image; image size <1.5 GB
- [ ] `POST /convert` round-trip tests pass for: png↔jpg, png↔webp, jpg↔heic, jpg↔avif, svg→png, gif→webp (animated preserved)
- [ ] `GET /formats` returns JSON catalog matching doc-forge shape
- [ ] `GET /health` returns engine availability per-engine
- [ ] MCP server tested with Claude Code (`claude mcp add image-forge ...`)
- [ ] Deployed to `images.jeffemmett.com`; Traefik routing live; Cloudflare tunnel green
- [ ] Infisical secrets wired (no hardcoded creds in compose)
- [ ] Documented in dev-ops README + Uptime Kuma monitor added

## Non-goals (this task)

- Animated WebP / animated GIF generation from video — that's media-forge (TASK-70)
- 3D model formats (gltf, obj, stl) — defer until consumer arrives
- Image AI ops (upscaling, inpainting, removal) — separate epic
<!-- SECTION:DESCRIPTION:END -->
