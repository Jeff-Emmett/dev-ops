#!/usr/bin/env bash
# gitea-actions stale-Running watchdog.
#
# act_runner v0.3.1 has a known reconciliation bug where it reports
# task completion to the Gitea server but the status update never lands
# in the action_run / action_run_job / action_task tables. Result: rows
# stay at status=2 (Running) forever, even though the runner already
# stopped the container and wrote the log. Over time the queue jams
# (we hit ~1,800 stale entries before the first manual cleanup on
# 2026-05-08), and new runs get Skipped because Gitea thinks the
# runner is busy.
#
# This watchdog finds rows that match the orphaned-terminal pattern —
#
#   status = 2 (Running)
#   AND stopped > 0      (act_runner DID report when it stopped)
#   AND age(stopped) > N (the timestamp landed long ago)
#
# — and forces them to status=4 (Failure). The actual outcome is
# recoverable from the per-task log file but isn't reconciled into the
# status field; failure is the safe assumption. Heuristic-only — runs
# that are still legitimately Running (status=2, stopped=0) are NEVER
# touched.
#
# Also catches runs with status=2 AND stopped=0 AND started+THRESHOLD
# elapsed (truly stuck/orphaned, no terminal report).
#
# Run from a systemd timer every 15 min. See watchdog-stale-runs.timer.
#
# Tracked in dev-ops backlog: TASK-HIGH.8 (root cause), TASK-MEDIUM.11
# (act_runner skip behavior).

set -euo pipefail

# Threshold in minutes — how long after `stopped` before we declare
# orphaned-terminal. 5 min is comfortable: the longest legitimate
# reconciliation lag observed is <30s.
STOPPED_THRESHOLD_MIN="${STOPPED_THRESHOLD_MIN:-5}"

# Threshold for status=2, stopped=0 (truly stuck — runner never even
# reported a stop). 60 min is well above the 3h job timeout in
# /data/config.yaml; if a run is past this without a stop signal,
# something is wrong.
STARTED_THRESHOLD_MIN="${STARTED_THRESHOLD_MIN:-60}"

DB_CONTAINER="${DB_CONTAINER:-gitea-db}"
DB_USER="${DB_USER:-gitea}"
DB_NAME="${DB_NAME:-gitea}"

run_sql() {
  docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" "$@"
}

orphaned_count_before=$(run_sql -tAc "
  SELECT count(*) FROM action_run
   WHERE status=2 AND ((
     stopped > 0 AND to_timestamp(stopped) < NOW() - INTERVAL '${STOPPED_THRESHOLD_MIN} minutes'
   ) OR (
     stopped = 0 AND started > 0 AND to_timestamp(started) < NOW() - INTERVAL '${STARTED_THRESHOLD_MIN} minutes'
   ));
" | tr -d '[:space:]')

if [[ "$orphaned_count_before" == "0" ]]; then
  exit 0
fi

# Fix runs first (and their joined jobs / tasks via the run id) — this
# is the order that matches Gitea's own state-update path so any
# server-side cache invalidations fire correctly.
run_sql <<SQL
BEGIN;

-- Run-level: the orphaned-terminal set
WITH orphaned_runs AS (
  SELECT id FROM action_run
   WHERE status=2 AND ((
     stopped > 0 AND to_timestamp(stopped) < NOW() - INTERVAL '${STOPPED_THRESHOLD_MIN} minutes'
   ) OR (
     stopped = 0 AND started > 0 AND to_timestamp(started) < NOW() - INTERVAL '${STARTED_THRESHOLD_MIN} minutes'
   ))
)
UPDATE action_run SET status=4 WHERE id IN (SELECT id FROM orphaned_runs);

-- Jobs of those runs
UPDATE action_run_job SET status=4
 WHERE status=2 AND run_id IN (
   SELECT id FROM action_run WHERE status=4 AND id IN (
     SELECT run_id FROM action_run_job WHERE status=2
   )
 );

-- Tasks of those jobs
UPDATE action_task SET status=4
 WHERE status=2 AND id IN (
   SELECT task_id FROM action_run_job WHERE status=4 AND task_id IS NOT NULL AND task_id > 0
 );

-- Also catch Waiting (status=1) that's older than STARTED_THRESHOLD.
-- These are runs queued behind orphaned ones and would never be picked
-- up — mark them Cancelled (5) to free the queue slot.
UPDATE action_run SET status=5
 WHERE status=1 AND created > 0
   AND to_timestamp(created) < NOW() - INTERVAL '${STARTED_THRESHOLD_MIN} minutes';
UPDATE action_run_job SET status=5
 WHERE status=1 AND run_id IN (SELECT id FROM action_run WHERE status=5);

COMMIT;
SQL

orphaned_count_after=$(run_sql -tAc "
  SELECT count(*) FROM action_run
   WHERE status=2 AND ((
     stopped > 0 AND to_timestamp(stopped) < NOW() - INTERVAL '${STOPPED_THRESHOLD_MIN} minutes'
   ) OR (
     stopped = 0 AND started > 0 AND to_timestamp(started) < NOW() - INTERVAL '${STARTED_THRESHOLD_MIN} minutes'
   ));
" | tr -d '[:space:]')

cleared=$((orphaned_count_before - orphaned_count_after))
echo "[gitea-watchdog] cleared ${cleared} stale Running run(s); ${orphaned_count_after} remain"
