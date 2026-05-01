---
id: TASK-72
title: 'clip-forge: remove wg-client sidecar after media-forge cutover'
status: To Do
assignee: []
created_date: '2026-05-01 19:00'
labels:
  - clip-forge
  - cleanup
  - wireguard
  - infrastructure
  - follow-up
dependencies:
  - TASK-70
priority: low
target_review_date: '2026-05-15'
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-70 cutover (2026-05-01) moved yt-dlp egress server-side into media-forge. clip-forge-worker no longer needs the wg-client WireGuard sidecar — yt-dlp now runs in the media-forge container with its own `HTTP_PROXY` knob (set when the WG client deploy lands there).

This task is the sidecar removal: edit clip-forge `docker-compose.yml` to delete the `wireguard` service + the `network_mode: service:wireguard` on the worker, restart the worker, verify a real clip-extraction job still works end-to-end (download + audio-extract via media-forge, no fallback triggered).

**Wait at least 2 weeks (2026-05-15)** of clean media-forge operation before touching this — the wg-client is the safety net. Until then, the worker has it but doesn't use it.

## Pre-flight check (run on 2026-05-15)

```bash
ssh netcup-full
# 1. Has any media-forge fallback been triggered? Look for "[media-forge] *unavailable" / "*hard error"
docker logs clip-forge-worker-1 2>&1 | grep -iE 'media-forge.*unavailable|media-forge.*hard'
# 2. Has clip-forge-worker hit yt-dlp directly recently? (Should be 0 — all yt-dlp goes through media-forge now)
docker logs clip-forge-worker-1 2>&1 | grep -i 'yt-dlp' | grep -v media-forge
# 3. Production /health on media-forge consistently green?
curl -fsS https://media.jeffemmett.com/health | jq .status
```

If all three are clean → proceed with removal.

## Acceptance Criteria

<!-- AC:BEGIN -->
- [ ] #1 wg-client / wireguard service removed from clip-forge docker-compose.yml
- [ ] #2 Worker `network_mode: service:wireguard` removed; worker on default network
- [ ] #3 Real clip-extraction job (YouTube → clip with subs) still produces correct output after removal
- [ ] #4 docker-compose.yml diff reviewed; commit on clip-forge main
<!-- AC:END -->

## Cross-references

- TASK-70 — parent (the cutover that made this safe)
- `dev-ops/netcup/media-forge-deploy.md` — operator notes for media-forge
