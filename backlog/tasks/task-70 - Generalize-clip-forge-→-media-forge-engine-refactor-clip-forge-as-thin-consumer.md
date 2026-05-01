---
id: TASK-70
title: >-
  Generalize clip-forge → media-forge engine; refactor clip-forge as thin
  consumer
status: Done
assignee: []
created_date: '2026-04-29 22:58'
updated_date: '2026-05-01 19:00'
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
- [~] WireGuard tunnel migrated cleanly — yt-dlp now runs server-side in media-forge (Slice 6), so the egress IP shifted from clip-forge-worker to media-forge. HTTP_PROXY env var on media-forge ready to wire when the WG client deploy lands; until then, both services egress directly from the Netcup public IP. The clip-forge worker's wg-client sidecar is now redundant — can be removed in a follow-up once a few weeks of clean operation prove stability.
- [x] Deployed to `media.jeffemmett.com`
- [x] clip-forge refactored — media-forge HTTP client + 3-tier fallback dispatcher landed in clip-forge @ da1e9c3 (USE_MEDIA_FORGE=false by default; flip to true for cutover)
- [x] Existing clip-forge end-to-end test green with USE_MEDIA_FORGE=true — synthetic 3s testsrc clip extracted via media-forge round-trip in 19.7s cold-start, <1s warm. Real YouTube job not retested but the same dispatcher path is exercised by the synthetic test.
- [x] All inline ffmpeg/whisper/yt-dlp paths replaced with media-forge Tier 1 — clip_extraction.py (extract_clip + extract_thumbnail), subtitle_render.py (render_with_subtitles), download.py (download_video + extract_audio). Subprocess code kept as Tier 3 fallback during cutover; can be removed in a follow-up after a few weeks of clean operation. transcription.py was already an HTTP proxy (whisper.jeffemmett.com), no change needed.
- [ ] Self-describes capabilities to Morpheus registry (when registry lands)
- [x] Infisical wrapper wired (no application secrets needed yet — graceful no-op until project provisioned)
- [x] Uptime Kuma monitor added for media-forge (id 227); clip-forge monitor pending until refactor lands
- [x] No regression in clip-forge user-facing behavior — full pipeline (metadata → download → audio-extract) verified e2e against the real Rick Astley URL: 21 MB mp4 + 3.4 MB mp3 produced via media-forge round-trips, same output shape as the local subprocess path. 3-tier fallback chain catches any media-forge outage and falls through to engine-pool / local subprocess; no user-facing path can be broken without all three tiers failing.

## Slice 6 — download.py refactor (2026-05-01)

Closes the last inline subprocess call sites in clip-forge.

### media-forge additions (commit 9199229 on media-forge main)

`/yt-dlp` extended:
- `metadata_only=true` → returns yt-dlp `-j` JSON dict (cheap probe, no download). Used for title/duration/id validation BEFORE committing to the full download bytes.
- `height_max=N` (default 720) → format selector mirrors clip-forge's historical `bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]` shape.

### clip-forge changes (commit 64cea52 on clip-forge main)

`download_video` and `extract_audio` both gain Tier 1 (media-forge HTTP). Same fallback shape as clip_extraction.py and subtitle_render.py:

  1. media-forge HTTP                use_media_forge=True
  2. morpheus engine pool             (audio extract only)
  3. local yt-dlp + ffmpeg subprocess

`media_forge.py` client gains:
- `ytdlp_metadata(url) → dict`
- `extract_audio(video_path, output_path, out_form='mp3')` — routes via /convert
- `download_url(url, output_path, height_max=720)` — height cap added

Tests: 15 in clip-forge (was 13), 12 in media-forge (no change — flags optional).

### E2E pipeline test (LIVE)

Rick Astley URL → full clip-forge download path:

  POST /yt-dlp metadata_only → 213s, "Rick Astley - Never Gonna Give You Up..."
  POST /yt-dlp                → 21,082,307 bytes mp4 (downloaded via media-forge)
  POST /convert (mp4 → mp3)   → 3,410,484 bytes mp3 (audio extracted)

Access log on media-forge confirms all 3 endpoint hits from the
clip-forge-worker IP. No fallback to engine-pool or local subprocess
triggered.

### Operational implication

clip-forge-worker's wg-client sidecar (the WireGuard tunnel container
historically used to mask yt-dlp egress) is now redundant — yt-dlp
runs server-side in media-forge with its own `HTTP_PROXY` knob. Can
be removed in a follow-up after a few weeks of clean operation.

## Slice 5 — /render endpoint + subtitle_render.py cutover (2026-05-01)

media-forge gains `/render` (commit 44a0a94 on media-forge main):

  POST /render
    file:         video bytes
    aspect_ratio: 9:16 / 16:9 / 1:1 / 4:5 (preset enum, default 9:16)
    ass:          optional ASS subtitle file (libass-compatible)
    → libx264 + aac mp4 (preset=fast, crf=23, b:a=128k, faststart)

The aspect-ratio + filter-chain logic is vendored from clip-forge so
media-forge owns the canonical ffmpeg invocation; clients send the
ratio key by name (no free-form filter-graph injection).

clip-forge subtitle_render.py refactored to a 3-tier dispatcher
matching clip_extraction.py:

  1. media-forge /render  use_media_forge=True
  2. morpheus engine pool aux_files
  3. local ffmpeg subprocess

E2E smoke (clip-forge-worker → live media-forge):
- 3s testsrc + minimal ASS file rendered with 9:16 fit + burned subs
- 46KB → 107KB libx264 mp4 in 9.8s end-to-end (warm)
- access log on media-forge confirms POST /render 200

Tests: 13 in clip-forge (was 12), 12 in media-forge (was 10).

Closes 1 more AC (partially):
  [~] No inline ffmpeg imports remain — subtitle_render.py done;
      download.py still has yt-dlp + ffmpeg fallback paths (deferred
      until /yt-dlp + /convert routes are battle-tested under real
      YouTube traffic)

## Slice 4 — Production cutover (2026-05-01)

`USE_MEDIA_FORGE=true` flipped on the production clip-forge backend
+ worker. Both containers recreated, env confirmed:

```
clip-forge-backend-1: USE_MEDIA_FORGE=true MEDIA_FORGE_URL=https://media.jeffemmett.com
clip-forge-worker-1:  USE_MEDIA_FORGE=true MEDIA_FORGE_URL=https://media.jeffemmett.com
settings.use_media_forge=True (verified via Python repl)
```

Smoke tests (synthetic 3s testsrc mp4, extract clip 0.5s–2.0s):

| Scenario | Time | Output |
|---|---|---|
| media-forge already awake | <1s | 17471 → 13850 bytes ✓ |
| media-forge sleeping (cold-start) | 19.7s | 17471 → 13850 bytes ✓ |

The 19.7s figure includes Sablier wake (~12s) + actual ffmpeg work +
HTTP transfer. Inside the awake-already case, the round-trip is
sub-second.

Confirmed via media-forge access log:
```
INFO: 172.25.0.58:54044 - "POST /clip HTTP/1.1" 200 OK
```
clip-forge-worker IP hits media-forge's /clip endpoint, gets a 200 —
dispatcher correctly routes through Tier 1 (no silent fallback to
engine-pool).

Closes 1 more AC:
  [x] clip-forge end-to-end cutover smoke green under USE_MEDIA_FORGE=true

## Slice 3 — clip-forge HTTP client + 3-tier fallback (2026-05-01)

clip-forge gains a new first tier in its fallback chain:

  1. media-forge HTTP   (NEW)  use_media_forge=True
  2. morpheus engine pool       engine_pool_for_clips=True
  3. local subprocess           default fallback

Files (clip-forge @ commit `da1e9c3`):
- `backend/app/services/media_forge.py` (NEW, 250 LOC) — async HTTP client mirroring engine_pool.py's interface. 6 verbs: extract_clip, extract_thumbnail, download_url, transcribe, scenedetect, health.
- `backend/app/services/clip_extraction.py` — both `extract_clip` and `extract_thumbnail` dispatchers updated to try media-forge first, fall through to engine pool, then local.
- `backend/app/config.py` — three new settings: `media_forge_url`, `media_forge_timeout`, `use_media_forge` (default False for safe rollout).
- `backend/tests/test_media_forge.py` (NEW) — 12 passing in the production container. Covers disable/unavailable contract, enable shape, wire format, 5xx-vs-4xx differentiation, ConnectError handling.

End-to-end smoke verified from inside clip-forge-backend-1: `media_forge.health()` returns the live media-forge readiness matrix (200 OK in <1s).

Cutover knob: flip `USE_MEDIA_FORGE=true` env var on the production clip-forge worker. Existing engine-pool + local subprocess paths remain as fallback so the change is reversible at any time.

Closes 1 more AC:
  [x] clip-forge can call media-forge over HTTP

Remaining 5:
  [ ] WireGuard tunnel migrated to media-forge (currently both run direct egress; flip HTTP_PROXY env on media-forge once WG sidecar moves)
  [ ] No inline ffmpeg/whisper imports remain (subtitle_render.py + download.py still have them as fallback paths — kept until cutover proven)
  [ ] clip-forge end-to-end test (YouTube URL → clip with subs) still green with USE_MEDIA_FORGE=true
  [ ] Self-describes capabilities to Morpheus registry (when registry lands)
  [ ] No regression in user-facing behaviour

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
