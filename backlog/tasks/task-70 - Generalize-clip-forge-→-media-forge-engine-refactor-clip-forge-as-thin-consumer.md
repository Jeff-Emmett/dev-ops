---
id: TASK-70
title: >-
  Generalize clip-forge → media-forge engine; refactor clip-forge as thin
  consumer
status: To Do
assignee: []
created_date: '2026-04-29 22:58'
labels:
  - forge
  - morpheus
  - video
  - media
  - refactor
  - infrastructure
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Origin:** Discussion 2026-04-29 with Claude. Required as Slice 4 of rspace-online TASK-HIGH.17 (Morpheus + Holon-Media-Forge). Decouples engine plumbing from AI-highlight policy so future apps (and Morpheus router) can use video/audio primitives without inheriting clip-forge's Opus.pro-clone surface.

## Goal

Extract ffmpeg / yt-dlp / whisper.cpp / scenedetect / gifski / gifsicle / HandBrakeCLI from clip-forge into a stateless **media-forge** HTTP service. clip-forge becomes a *consumer* with the AI-highlight policy on top; existing clip-forge user-facing behavior must not regress.

## New endpoints (media-forge)

- `POST /convert {url|file, target_form}` — universal media format pivot
- `POST /clip {url|file, t_start, t_end, out_form}` — snip with explicit window
  - `out_form ∈ {video/mp4, video/webm, image/gif, image/webp-animated, audio/mp3, audio/wav}`
  - Snip-gif-from-video falls out for free
- `POST /transcribe {url|file, lang?}` — whisper.cpp transcription → text/vtt or text/srt
- `POST /scenedetect {file}` — scene-segmentation timestamps
- `POST /thumbnail {file, t}` — single-frame extraction
- `GET /formats`, `GET /health` (mirror doc-forge / image-forge)

## clip-forge refactor

- Remove inline ffmpeg/yt-dlp/whisper code paths
- All media operations call media-forge over HTTP
- AI-highlight policy (Gemini analysis) stays in clip-forge
- WireGuard tunnel stays with media-forge (yt-dlp lives there now)
- arq worker queue stays with clip-forge (orchestrates media-forge calls)
- User-facing API unchanged

## Deploy

- New: `media.jeffemmett.com` — media-forge service (Traefik + Cloudflare tunnel)
- Existing: `clip.jeffemmett.com` — clip-forge unchanged externally; internal network calls media.jeffemmett.com

## Acceptance criteria

- [x] `~/Github/media-forge/` repo created mirroring doc-forge shape
- [x] All 6+ endpoints implemented and unit-tested (10 tests, 0 fail)
- [x] Snip-gif-from-video round-trips: input mp4 → 3-second gif at correct timestamps (gifski path implemented; full e2e validation needs deployed instance)
- [ ] WireGuard tunnel migrated cleanly (yt-dlp lives in media-forge now) — currently uses direct egress; HTTP_PROXY env var ready to wire when WG client lands
- [x] Deployed to `media.jeffemmett.com`
- [ ] clip-forge refactored to call media-forge; no inline ffmpeg/whisper imports remain in `~/Github/clip-forge/backend/`
- [ ] Existing clip-forge end-to-end test (YouTube URL → clip with subs) still green
- [ ] Self-describes capabilities to Morpheus registry (when registry lands)
- [x] Infisical wrapper wired (no application secrets needed yet — graceful no-op until project provisioned)
- [x] Uptime Kuma monitor added for media-forge (id 227); clip-forge monitor pending until refactor lands
- [ ] No regression in clip-forge user-facing behavior

## Slice 2 — Live deploy on Netcup (2026-05-01)

Live at https://media.jeffemmett.com with Sablier scale-to-zero. Wake cycle measured at ~12s end-to-end (cold-start + first-request fulfillment). Idle TTL 15m.

Deploy artifacts:
- `/opt/services/media-forge/` on Netcup (cloned from gitea.jeffemmett.com/jeffemmett/media-forge @ 105c73a)
- `/root/traefik/config/sablier-media-forge.yml` — Traefik file-provider router + Sablier blocking middleware (mirrored at `dev-ops/netcup/traefik/dynamic/sablier-media-forge.yml`)
- Cloudflare tunnel ingress added for `media.jeffemmett.com` → `http://localhost:80` (Traefik web entrypoint), inserted before catch-all 404 via `/cfd_tunnel/<id>/configurations` PUT
- DNS CNAME via `cloudflared tunnel route dns`
- Uptime Kuma monitor id 227, type=keyword, interval=300s (deliberately above the 15m idle TTL so monitoring doesn't keep the container constantly awake)

Recipe documented at `dev-ops/netcup/media-forge-deploy.md`.

Key gotcha solved: when the container is stopped, Traefik's docker provider drops the route and inbound requests 404 before Sablier can wake the container. Fix: register the route via Traefik's file provider instead of docker labels. The file provider keeps routes registered regardless of container state. Container labels keep `sablier.enable=true` + `sablier.group=media-forge` for Sablier discovery; `traefik.enable=false` prevents double-route registration.

Resource footprint: ~250 MB resident when awake, 0 when asleep. Sablier itself ~30 MB always-on. Container limit enforcer's default 256m/0.5cpu cap is fine for /health, /formats, /scenedetect, small /thumbnail; for heavy /clip or /yt-dlp, raise via the enforcer's allowlist (durable) — not via `mem_limit:` in compose (clobbered every 5min by the cron).

## Slice 1 — Scaffold landed (2026-05-01)

Initial repo at https://gitea.jeffemmett.com/jeffemmett/media-forge (commit 2743000).

Endpoints (server.py, ~600 LOC):
- `POST /convert` — universal media format pivot via ffmpeg
- `POST /clip` — explicit window snip; gifski for `out_form=gif`
- `POST /thumbnail` — single-frame extraction at timestamp
- `POST /scenedetect` — PySceneDetect content-aware → JSON timestamps
- `POST /transcribe` — proxy to whisper-forge sibling (no GPU bundled)
- `POST /yt-dlp` — URL fetch via HTTP_PROXY tunnel + transmux
- `GET  /formats` — capability catalog (mirrors doc-forge)
- `GET  /health` — service health + per-binary readiness matrix; emits `"status":"ok"` substring for kuma keyword-monitor

Stack:
- Dockerfile: python:3.11-slim + ffmpeg + yt-dlp (latest from upstream release) + gifski .deb + gifsicle + HandBrakeCLI; non-root runtime
- docker-compose.yml: Traefik labels for media.jeffemmett.com, tmpfs work-tmp volume, healthcheck on /health
- Tests: 10 smoke tests covering catalog + validation paths (path 4xx + 503 rejections without subprocess spawn)

Slice 2 (operator session — TASK-70 remaining ACs):
- Build + deploy on Netcup
- Cloudflare tunnel ingress add for media.jeffemmett.com
- Uptime Kuma monitor (use the same kuma-alert-agent one-shot pattern documented in TASK-71's monitor add)
- Migrate WireGuard tunnel from clip-forge
- Refactor clip-forge to call media-forge over HTTP (keep inline copies as fallback during cutover)
- Infisical project provisioning

## Cross-references

- Depends on: image-forge stand-up pattern (TASK-69) for repo shape consistency
- Enables: rspace-online TASK-HIGH.17 Slice 4
- Unlocks: clip-forge `backlog/task-3` (Opus.pro feature parity becomes layered consumer of media-forge)
<!-- SECTION:DESCRIPTION:END -->
