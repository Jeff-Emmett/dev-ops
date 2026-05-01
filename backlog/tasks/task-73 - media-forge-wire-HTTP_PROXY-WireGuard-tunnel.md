---
id: TASK-73
title: 'media-forge: wire HTTP_PROXY (WireGuard tunnel) for yt-dlp egress'
status: To Do
assignee: []
created_date: '2026-05-01 19:00'
labels:
  - media-forge
  - wireguard
  - yt-dlp
  - infrastructure
  - follow-up
dependencies:
  - TASK-70
priority: medium
target_review_date: '2026-05-15'
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
media-forge already supports an `HTTP_PROXY` env that yt-dlp uses for egress. Setting this to a SOCKS5 endpoint backed by a WireGuard tunnel keeps the Netcup public IP off YouTube's rate-limit list (the same reason clip-forge originally ran a wg-client sidecar — TASK-70 Slice 6 moved that responsibility server-side).

Right now `HTTP_PROXY` is unset → yt-dlp egresses direct from Netcup's public IP. That's fine for current low volume but will hit rate limits as clip-forge scales.

This task: deploy a WireGuard client container alongside media-forge with a SOCKS5 server (or use upstream's public WG VPN provider), set `HTTP_PROXY=socks5://wg-client:1080` on media-forge, verify yt-dlp egresses through the tunnel.

**Trigger this task when YouTube starts rate-limiting** (HTTP 429 / "Sign in to confirm you're not a bot" responses to yt-dlp). Until then it's preventative; the fix is one env var + one sidecar away.

## Pre-flight check

```bash
ssh netcup
# Check media-forge logs for rate-limit signals from yt-dlp
docker logs media-forge 2>&1 | grep -iE '429|rate.limit|sign.in.to.confirm'
```

If 0 hits over 4 weeks of operation: maybe defer indefinitely. If hits start appearing: this becomes the next deploy.

## Approach

Reuse the existing wg-client container image from clip-forge (currently at `/opt/clip-forge/wg-client/`). Same image, just deployed alongside media-forge. SOCKS5 stack:

1. WireGuard tunnel container — reuse clip-forge's wg-client config (just the WG peer).
2. dante-server or microsocks container on the WG network — exposes SOCKS5 :1080.
3. media-forge env: `HTTP_PROXY=socks5://wg-client:1080`.
4. yt-dlp inherits `HTTP_PROXY` from env automatically (it respects standard proxy env vars).

Alternative: if the upstream WG VPN provider has a SOCKS5 endpoint already, skip step 2.

## Acceptance Criteria

<!-- AC:BEGIN -->
- [ ] #1 wg-client container deployed alongside media-forge on the same Docker network
- [ ] #2 SOCKS5 :1080 reachable from inside media-forge
- [ ] #3 `HTTP_PROXY=socks5://wg-client:1080` set on media-forge container
- [ ] #4 `curl ipinfo.io` from inside media-forge shows the WG-tunneled IP, not Netcup's public IP
- [ ] #5 yt-dlp on a rate-limited test URL succeeds via the tunnel (regression-free if not currently rate-limited)
- [ ] #6 No regression: existing `/clip`, `/render`, `/convert` still 200 (these don't egress externally)
<!-- AC:END -->

## Cross-references

- TASK-70 Slice 6 — moved yt-dlp into media-forge, set up the env-var hook for this task
- TASK-72 — clip-forge wg-client removal, can fully proceed once this lands (the WG tunnel becomes irrelevant on the clip-forge side)
- `/opt/clip-forge/wg-client/` — the existing WG config to reuse
