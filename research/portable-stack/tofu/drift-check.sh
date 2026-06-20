#!/usr/bin/env bash
# TASK-415.10 — drift-as-audit. Run on a cron; a structural diff in the live
# holarchy that OpenTofu manages = an out-of-band mutation = an audit signal.
#
#   exit 0 = in sync
#   exit 2 = drift detected (alert)
#   exit 1 = error running plan
set -euo pipefail

cd "$(dirname "$0")"

TOFU="${TOFU_BIN:-tofu}"
"$TOFU" init -input=false -no-color >/dev/null

set +e
"$TOFU" plan -input=false -no-color -detailed-exitcode -out=/dev/null
code=$?
set -e

case "$code" in
  0) echo "[drift-check] holarchy structure in sync"; exit 0 ;;
  2)
    echo "[drift-check] DRIFT: live structure diverged from declared state"
    # Wire to alerting, e.g. uptime-kuma push or the kuma-alert-agent.
    if [ -n "${DRIFT_ALERT_URL:-}" ]; then
      curl -fsS -m 10 "$DRIFT_ALERT_URL" >/dev/null || true
    fi
    exit 2
    ;;
  *) echo "[drift-check] error running plan (exit $code)"; exit 1 ;;
esac
