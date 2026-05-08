---
id: TASK-HIGH.8
title: Investigate Gitea Actions queue jam — 1800+ stale Running entries
status: In Progress
assignee: []
created_date: '2026-05-08 18:42'
updated_date: '2026-05-08 20:57'
labels: []
dependencies: []
parent_task_id: TASK-HIGH
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Symptom:** Pushes to rspace-online (and possibly other repos) trigger workflow runs that stay at status=2 (Running) in the Gitea DB long after the runner has finished and cleaned up the job container. The queue accumulated ~1,800 stale entries before being mass-cleared in the 2026-05-08 deploy session.

**Manual cleanup applied (2026-05-08):**
```sql
UPDATE action_run SET status=4 WHERE status=2;
UPDATE action_run SET status=5 WHERE status=1;
UPDATE action_run_job SET status=4 WHERE status=2;
UPDATE action_run_job SET status=5 WHERE status=1;
UPDATE action_task SET status=4 WHERE status=2;
UPDATE action_task SET status=5 WHERE status=1;
```
Plus `docker restart gitea-runner`. Cleared the queue but the underlying cause (act_runner v0.3.1 not reconciling final status with Gitea-server on completion) remains.

**Root cause hypothesis:** when act_runner finishes a job container, it should report Success/Failure to Gitea via the runner protocol. If the runner crashes, restarts, or loses its connection mid-job, the status update never lands and the run stays Running forever in Gitea's DB. New pushes don't break, but the visible queue grows over time. Eventually the runner's concurrency slot count is consumed by ghost runs.

**Investigation:**
- act_runner source: https://gitea.com/gitea/act_runner — look at how it reports task termination
- Gitea source: `models/actions/run.go` — the status reconciliation logic on the server side
- Compare against Gitea v1.23+ which reportedly added a stale-run watchdog

**Acceptance criteria:**
- [ ] Identify the failure mode (logs from a known-stuck run)
- [ ] Mitigation: either upgrade act_runner / Gitea, OR add a cron that auto-fails any run with status=2 + stopped > 0 + age > 1h
- [ ] Document in dev-ops README
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**2026-05-08 — operational mitigation deployed.**

`netcup/gitea/watchdog-stale-runs.sh` installed at /opt/scripts/ on Netcup, enabled via systemd timer (every 15 min). The script targets the orphaned-terminal pattern (status=2 AND stopped > 0 AND age(stopped) > 5 min) and marks affected rows Failure (status=4). Also cancels Waiting (status=1) runs older than 60 min that are queued behind orphans.

Queue is now actively maintained: even if act_runner v0.3.1 keeps failing to reconcile, the watchdog catches the leak within 15 min of each occurrence.

**Root cause investigation still open:**
- act_runner v0.3.1 is Gitea's first-party runner; the reconciliation race is likely in the Tasks RPC stream between the runner and Gitea server
- Gitea v1.23+ (we're on an older version) ships a server-side watchdog that addresses this; checking it would supersede the timer
- act_runner v0.4.0+ may have the fix; release notes should be reviewed before bumping

**Before closing this task:**
- [ ] Confirm watchdog has been running cleanly for ≥ 7 days (no false positives, queue stays bounded)
- [ ] Either: upgrade Gitea + act_runner to a version with native reconciliation, OR document why we're keeping the watchdog

Marking In Progress until at least the first verification window (7 days).

**2026-05-08 — diagnostic data from production confirms the bug pattern + watchdog effectiveness.**

Real-world test case captured:
- run 1845, task 1924: workflow forge-jmmj-tests for rspace-online commit 64fcc8f6
- task started 20:45:54 UTC, **stopped 20:46:53 UTC** (only 59 seconds)
- task.status, action_run_job.status, action_run.status all stuck at 2 (Running) for 8+ minutes despite the stopped timestamp being set
- watchdog at 21:04 UTC caught it: status flipped to 4 (Failure)
- queue went to 0 Running / 0 Waiting

Upstream context (from GitHub issue research):
- Gitea issue #35956 (open, 2025-11-14) — exact symptom on 1.25.1, maintainer @lunny: 'The complete job sometimes becomes very slow which is a known issue.'
- Gitea issue #35645 (closed 2025-10-15) — different cause (actions_log permission denied on rootless image switch); not our case (we're on the non-rootless image, actions_log writable)
- The user who reported #35956 confirmed the symptom does NOT occur on 1.24.1 — so the bug is between 1.24.1 and 1.25.1, with related-but-distinct issues stretching back. Our 1.21 is older still, predating the 1.24 baseline.

Watchdog tuning: STOPPED_THRESHOLD_MIN reduced from 5 → 3 min. In healthy operation reconciliation is sub-second, so 3 min is well past any legitimate lag. Trade-off accepted: faster recovery vs marginal false-positive risk on transient network glitches between runner and Gitea.

Watchdog now cleared 6 stale entries across the first 4 cycles since install; queue stays bounded (≤4 Running, the runner's true capacity).

**Open question on permanent fix:** upgrade Gitea 1.21 → 1.24.x (skip 1.25.x given the regression). Bigger move requiring a maintenance window and DB schema validation. Leaving the watchdog as the operational mitigation while that upgrade is planned separately.
<!-- SECTION:NOTES:END -->
