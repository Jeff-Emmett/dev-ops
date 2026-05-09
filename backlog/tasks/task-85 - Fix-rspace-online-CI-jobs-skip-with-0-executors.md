---
id: TASK-85
title: 'Fix rspace-online CI: jobs skip with "0 executors"'
status: To Do
assignee: []
created_date: '2026-05-09 15:45'
updated_date: '2026-05-09 15:52'
labels:
  - ci
  - gitea-actions
  - rspace-online
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Problem:** All ci.yml runs on rspace-online have status=skipped (6) when ≥3 workflows trigger on the same push. The runner has capacity=2; with 4 workflows (aap-surface-gate, ci.yml, forge-jmmj-tests, integral-tests), ci.yml frequently gets skipped instead of queued.

**Two bugs fixed this session (2026-05-09), CI now meaningfully runs:**

1. **Repo secrets missing.** `REGISTRY_TOKEN`, `REGISTRY_USER`, `DEPLOY_HOST`, `DEPLOY_SSH_KEY` existed at user level (owner_id=jeffemmett, repo_id=0) but Gitea didn't inherit them into repo-scoped workflow context. **Fix:** `INSERT INTO secret (owner_id, repo_id, name, data, ...) SELECT 0, 109, name, data, ... FROM secret WHERE owner_id=jeffemmett AND repo_id=0 AND name IN (...)`. Verified present.

2. **Workflow's `container: docker:cli` was unrunnable.** act_runner has `privileged: false`; nested DinD failed silently with "0 executors". **Fix:** dropped `container:` directive entirely. Workflow now uses runner's default node:20-bookworm-slim with Docker CE installed via apt from upstream repo (Debian's docker.io is too old for `--build-context`). Verified: `task 2008` for commit ca0fe280 actually started building, hit `--build-context unknown flag` at the OLD docker stage (now fixed by Docker CE install in v2 commit 743745e9).

**Remaining issue: act_runner stale-task + concurrency interaction**

When 4 workflows trigger simultaneously and runner has capacity=2:
- 2 workflows pick up tasks
- The other 2 should queue but instead get status=6 (skipped)
- The 2 picked-up workflows run, set `stopped` timestamp, but never reconcile to status=3/4 (the existing TASK-MEDIUM.11 act_runner bug)
- Watchdog runs every 15 min and clears stale, but a new push triggers all 4 workflows fresh

**Fix candidates (smallest first):**
1. Increase runner capacity from 2 to 4 (in `/data/config.yaml` inside gitea-runner container) — may run into RAM ceiling; Netcup is 57Gi/62Gi.
2. Run watchdog more aggressively (1-min cadence vs 15-min).
3. Upgrade act_runner past v0.6.1 to a version with proper task reconciliation (depends on upstream fix landing for the stale-task bug).
4. Reduce noise: combine aap-surface-gate, forge-jmmj-tests, integral-tests into a single workflow with sequential jobs so they take 1 capacity slot total instead of 3.

**Manual deploy works in the meantime:**
```bash
ssh netcup-full
cd /opt/websites/rspace-online && \
  docker build --build-context encryptid-sdk=/opt/websites/encryptid-sdk \
    -t localhost:3000/jeffemmett/rspace-online:latest . && \
  docker compose up -d --force-recreate rspace
```
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ci.yml run completes status=success on a fresh push to main
- [ ] #2 Image localhost:3000/jeffemmett/rspace-online:<sha> visible in registry tags after push
- [ ] #3 Deploy step recreates rspace-online container with new image
- [ ] #4 Smoke test step returns HTTP 2xx and triggers no rollback
<!-- AC:END -->
