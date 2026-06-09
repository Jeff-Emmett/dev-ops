---
id: TASK-92
title: Fix rspace-online OOM crash-loop — in-memory DocStore exceeds container limit
status: To Do
assignee: []
created_date: '2026-05-21 23:55'
labels:
  - incident
  - rspace-online
  - memory
  - netcup
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Incident (2026-05-22 ~01:00 UTC)

`rspace-online` on Netcup OOM-crash-looped **131 times** (every ~60s), churning 2.6 GB alloc/free each cycle. On a server already at 100% swap this thrashed memory and made other rApps unresponsive. Resolved by `docker stop rspace-online` at 01:52 — server recovered (load 14 → 8), all other rApps healthy. **rspace-online is intentionally left stopped; rspace.online is down.**

## Root cause

`rspace-online` keeps an **in-memory document store** (`[DocStore]` / `SyncInstance`) and loads all docs into memory on boot. Working-set settles at **~2.61 GB** — just over the container's **2.5 GiB `mem_limit`** (2684354560 bytes) → deterministic cgroup OOM (`constraint=CONSTRAINT_MEMCG`), not a slow leak. Triggered by deploy of image `bb1bff47` (built 2026-05-21 21:50 UTC).

A plain `docker start` will re-enter the loop immediately.

## Fix options

1. **App-side (preferred):** bound the in-memory DocStore — lazy-load / LRU-capped cache / pagination — so steady-state RSS stays well under the limit. Code lands in the **rspace-online repo**, not dev-ops.
2. **Ops stopgap:** shed Netcup RAM elsewhere, then raise `rspace-online` `mem_limit` to ~4 GB. Buys time but the working-set will keep growing.

## Notes
- Diagnosis tell: cgroup OOM names the offending container's scope — `journalctl -k | grep CONSTRAINT_MEMCG`.
- `rspace-online-dev` and `rspace-zk-staging` are unaffected and still Up.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Confirm in the rspace-online codebase why DocStore/SyncInstance holds the full working-set in memory (no cap / eager load)
- [ ] #2 App-side fix implemented: in-memory doc store is bounded (lazy-load or LRU-capped) so steady-state RSS stays safely under the container limit
- [ ] #3 If the app fix is deferred: sufficient Netcup RAM shed and rspace-online mem_limit raised to ~4 GB, with the tradeoff documented
- [ ] #4 rspace-online restarted and stable — no OOM kills and RestartCount stops climbing for at least 1 hour
- [ ] #5 rspace.online responds HTTP 200 end-to-end (curl + browser check)
- [ ] #6 A memory-ceiling alert added (Uptime Kuma or OOM tier) so a recurrence is caught before it crash-loops
<!-- AC:END -->
