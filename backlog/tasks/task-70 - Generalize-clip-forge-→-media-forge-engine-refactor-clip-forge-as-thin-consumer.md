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

- [ ] `~/Github/media-forge/` repo created mirroring doc-forge shape
- [ ] All 6+ endpoints implemented and unit-tested
- [ ] Snip-gif-from-video round-trips: input mp4 → 3-second gif at correct timestamps
- [ ] WireGuard tunnel migrated cleanly (yt-dlp lives in media-forge now)
- [ ] Deployed to `media.jeffemmett.com`
- [ ] clip-forge refactored to call media-forge; no inline ffmpeg/whisper imports remain in `~/Github/clip-forge/backend/`
- [ ] Existing clip-forge end-to-end test (YouTube URL → clip with subs) still green
- [ ] Self-describes capabilities to Morpheus registry (when registry lands)
- [ ] Infisical secrets wired
- [ ] Uptime Kuma monitors added for both services
- [ ] No regression in clip-forge user-facing behavior

## Cross-references

- Depends on: image-forge stand-up pattern (TASK-69) for repo shape consistency
- Enables: rspace-online TASK-HIGH.17 Slice 4
- Unlocks: clip-forge `backlog/task-3` (Opus.pro feature parity becomes layered consumer of media-forge)
<!-- SECTION:DESCRIPTION:END -->
