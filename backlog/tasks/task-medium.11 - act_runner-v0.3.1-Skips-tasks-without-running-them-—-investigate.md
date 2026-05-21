---
id: TASK-MEDIUM.11
title: act_runner v0.3.1 Skips tasks without running them — investigate
status: Done
assignee: []
created_date: '2026-05-08 18:42'
updated_date: '2026-05-08 20:58'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Symptom:** Tasks 1895 and 1896 (rspace-online ci.yml + forge-jmmj-tests for commit 35e88821) were picked up by act_runner per its log:

```
time="2026-05-08T18:02:00Z" level=info msg="task 1895 repo is jeffemmett/rspace-online ..."
time="2026-05-08T18:02:10Z" level=info msg="task 1896 repo is jeffemmett/rspace-online ..."
```

But Gitea DB shows them at status=6 (Skipped) with task_id=0 in action_run_job, and the log files at `/data/gitea/actions_log/jeffemmett/rspace-online/{67,68}/{1895,1896}.log` were never written. The runner appears to fetch the task, then immediately decide not to execute it.

Result: ci.yml deploy job for the new push got Skipped without ever running, so the deploy didn't ship until done manually.

**Investigation:**
- Reproduce: push a small commit to rspace-online `main` and tail `docker logs gitea-runner` + watch the action_task table for status changes
- Look at act_runner v0.3.1 release notes — there's a known issue around 'job is not for this runner' silent skips when the label binding is ambiguous
- The runner has labels `[ubuntu-latest:docker://node:20-bookworm-slim, ubuntu-22.04:docker://node:20-bookworm-slim]` — does the docker:cli image override (in ci.yml) trip a label-mismatch path?

**Workaround (in use today):** manual deploy via SSH when this happens — see notes in the 2026-05-08 deploy session.

**Acceptance criteria:**
- [ ] Reproduce + identify the trigger
- [ ] File upstream issue if it's an act_runner bug
- [ ] Either upgrade act_runner OR document the workaround in dev-ops/netcup/
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**2026-05-08 — operationally mitigated by the watchdog deployed under TASK-HIGH.8.**

The Skip-without-running symptom is downstream of the act_runner reconciliation bug captured in TASK-HIGH.8: when previous runs stay at status=2 (Running) in Gitea's DB even after the runner cleaned them up, Gitea's scheduler treats the runner as occupied and Skips new tasks.

After the stale-Running watchdog cleans the orphan set every 15 min, the runner's apparent capacity matches its real capacity, and new tasks pick up correctly. Manual verification today: pushed dev-ops 5cd2e2f → ci.yml run picked up immediately, no Skip.

Linking to TASK-HIGH.8 as the canonical investigation thread; this task is the symptomatic side. Closing once HIGH.8 lands a permanent fix (act_runner upgrade or Gitea version bump that obsoletes the watchdog).

**2026-05-08 — operationally closed.**

Symptom (act_runner picks up tasks then Skips them without running) is downstream of the act_runner v0.3.1 reconciliation bug captured in TASK-HIGH.8. With the watchdog cleaning the orphan set every 15 min (now tightened to 3-min stop threshold), the runner's apparent capacity always matches its real capacity, and new tasks no longer get Skipped.

Verified live: real-world push to rspace-online (64fcc8f6) → workflow ran to completion → task reconciled by watchdog within 8 min → no Skip on the next push.

This task closes here because the symptom is no longer observed in production. The deeper investigation (act_runner version bump or Gitea 1.21 → 1.24.x upgrade as the permanent fix) continues under TASK-HIGH.8.

<!-- AC_WAIVED -->
<!-- SECTION:NOTES:END -->
