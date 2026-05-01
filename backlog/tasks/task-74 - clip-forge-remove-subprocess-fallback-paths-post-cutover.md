---
id: TASK-74
title: 'clip-forge: remove subprocess fallback paths after cutover proven stable'
status: To Do
assignee: []
created_date: '2026-05-01 19:00'
labels:
  - clip-forge
  - cleanup
  - refactor
  - follow-up
dependencies:
  - TASK-70
priority: low
target_review_date: '2026-05-22'
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-70 Slices 3-6 added media-forge as Tier 1 in clip-forge's 3-tier dispatch chain:

  1. media-forge HTTP   (NEW — production cutover via USE_MEDIA_FORGE=true)
  2. morpheus engine pool
  3. local ffmpeg / yt-dlp subprocess

Tiers 2 & 3 stayed as safety nets during cutover. Once Tier 1 has been
exercised continuously without falling through for ~3 weeks (target
review 2026-05-22), the inline subprocess code in clip-forge can be
removed. This shrinks clip-forge's container, removes dead branches
from the dispatcher, and strengthens the "thin consumer" property
that TASK-70 set out to establish.

## Pre-flight check (run on 2026-05-22)

Look for ZERO fallback events in the last 3 weeks:

```bash
ssh netcup-full
docker logs --since 504h clip-forge-worker-1 2>&1 | \
  grep -iE 'media-forge.*unavailable|engine-pool.*falling.back|local subprocess'
```

If clean → proceed. If any fallbacks fired, investigate the root cause
first before removing the safety net.

## Removals

In `~/Github/clip-forge/backend/app/services/`:

1. **clip_extraction.py**
   - `_ffmpeg_via_pool()` helper
   - `_extract_clip_via_pool()` and `_extract_thumbnail_via_pool()`
   - The Tier 2 + Tier 3 branches in `extract_clip()` and `extract_thumbnail()`
   - Final shape: just media-forge with a clean error if it fails

2. **subtitle_render.py**
   - `_render_via_pool()` helper
   - `_build_filter_chain()` (now lives in media-forge)
   - The Tier 2 + Tier 3 branches in `render_with_subtitles()`
   - The local `tempfile` ASS write (no longer needed)

3. **download.py**
   - `import yt_dlp` and the `yt_dlp.YoutubeDL(...)` block
   - The local `ffmpeg` subprocess in `extract_audio()`
   - `_base_opts()` (yt-dlp options helper)
   - Cookies file handling (also moves to media-forge if needed)

4. **engine_pool.py**
   - Either delete entirely (if the morpheus engine pool isn't used elsewhere) or keep for the morpheus router's own use cases

5. **clip-forge Dockerfile**
   - Remove ffmpeg / yt-dlp / cookies install
   - Image size should drop ~600 MB → ~150 MB (no media binaries)

## Acceptance Criteria

<!-- AC:BEGIN -->
- [ ] #1 No fallback events in last 504h (3 weeks) of worker logs (pre-flight check)
- [ ] #2 _ffmpeg_via_pool / _extract_clip_via_pool / _extract_thumbnail_via_pool removed from clip_extraction.py
- [ ] #3 _render_via_pool / _build_filter_chain removed from subtitle_render.py
- [ ] #4 import yt_dlp + local ffmpeg subprocess removed from download.py
- [ ] #5 ffmpeg / yt-dlp install removed from clip-forge Dockerfile
- [ ] #6 Real e2e test (YouTube → clip with subs) still green
- [ ] #7 Image size measurably smaller (target: <200 MB after removal)
<!-- AC:END -->

## Cross-references

- TASK-70 — parent (the cutover that made this possible)
- TASK-72 — wg-client sidecar removal, complementary cleanup
