#!/usr/bin/env bash
# Engine pool latency + failure-spike probe for Uptime Kuma.
#
# Runs every 5 min on Netcup. Pulls morpheus-engine-pool's /stats
# endpoint and pushes per-engine median_ms (as the heartbeat ping
# value) plus p95, sample count, queue depth, and failed-count
# delta (as the message) to four push monitors — one per engine.
#
# Status logic:
#   up   — engine pool reachable AND failed-count didn't grow since
#          last poll. ping = median_ms; n=0 is normal for idle engines
#          (whisper/libvips on quiet days), ping=0 there.
#   down — pool unreachable, OR failed-count rose by ≥1 in the
#          interval (a fresh worker error on this engine — Kuma's
#          email channel fires).
#
# Per-engine state lives at /var/lib/uptime-kuma-engine-pool-probe/
# <engine>.failed (last-known failed count). Probe creates the dir on
# first run; missing files mean "no prior state, suppress alarm and
# seed". This avoids alarming on the FIRST run after the probe ships.
#
# Push tokens are loaded from /etc/uptime-kuma-push.env (mode 600,
# root-only). Empty/unset tokens are skipped gracefully — register
# monitors lazily.
set -u

ENV_FILE="/etc/uptime-kuma-push.env"
if [[ ! -r "$ENV_FILE" ]]; then
  echo "missing $ENV_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

KUMA_HOST="status.jeffemmett.com"
KUMA_BASE="http://127.0.0.1"
STATE_DIR="/var/lib/uptime-kuma-engine-pool-probe"
mkdir -p "$STATE_DIR"

STATS_JSON=$(docker exec engine-pool-server curl -fsS -m 10 \
  "http://localhost:8000/stats" 2>/dev/null) || STATS_JSON=""

push() {
  local token="$1" engine="$2" status="$3" ping="$4" msg="$5"
  if [[ -z "$token" ]]; then
    return 0  # monitor not yet registered
  fi
  curl -fsS -m 10 -H "Host: ${KUMA_HOST}" \
    "${KUMA_BASE}/api/push/${token}?status=${status}&ping=${ping}&msg=${msg}" \
    >/dev/null || echo "push failed for ${engine}" >&2
}

if [[ -z "$STATS_JSON" ]]; then
  for tup in \
    "${ENGINE_POOL_FFMPEG_PUSH_TOKEN:-}|ffmpeg" \
    "${ENGINE_POOL_WHISPER_PUSH_TOKEN:-}|whisper" \
    "${ENGINE_POOL_IMAGEMAGICK_PUSH_TOKEN:-}|imagemagick" \
    "${ENGINE_POOL_LIBVIPS_PUSH_TOKEN:-}|libvips"; do
    IFS='|' read -r token engine <<< "$tup"
    push "$token" "$engine" "down" "0" "engine-pool+unreachable"
  done
  exit 1
fi

# Parse the response in one Python pass, emitting all four engines'
# n / median / p95 / queue.{waiting,active,failed} as shell vars.
eval "$(printf '%s' "$STATS_JSON" | python3 -c '
import sys, json
d = json.load(sys.stdin)["engines"]
for e in ("ffmpeg", "whisper", "imagemagick", "libvips"):
    bucket = d.get(e, {})
    q = bucket.get("queue") or {}
    n = bucket.get("n") or 0
    median = bucket.get("median_ms") or 0
    p95 = bucket.get("p95_ms") or 0
    waiting = q.get("waiting") or 0
    active = q.get("active") or 0
    failed = q.get("failed") or 0
    pfx = e.upper()
    print(f"{pfx}_N={n}")
    print(f"{pfx}_MEDIAN={median}")
    print(f"{pfx}_P95={p95}")
    print(f"{pfx}_WAITING={waiting}")
    print(f"{pfx}_ACTIVE={active}")
    print(f"{pfx}_FAILED={failed}")
' )"

for tup in \
  "${ENGINE_POOL_FFMPEG_PUSH_TOKEN:-}|ffmpeg|${FFMPEG_N}|${FFMPEG_MEDIAN}|${FFMPEG_P95}|${FFMPEG_WAITING}|${FFMPEG_ACTIVE}|${FFMPEG_FAILED}" \
  "${ENGINE_POOL_WHISPER_PUSH_TOKEN:-}|whisper|${WHISPER_N}|${WHISPER_MEDIAN}|${WHISPER_P95}|${WHISPER_WAITING}|${WHISPER_ACTIVE}|${WHISPER_FAILED}" \
  "${ENGINE_POOL_IMAGEMAGICK_PUSH_TOKEN:-}|imagemagick|${IMAGEMAGICK_N}|${IMAGEMAGICK_MEDIAN}|${IMAGEMAGICK_P95}|${IMAGEMAGICK_WAITING}|${IMAGEMAGICK_ACTIVE}|${IMAGEMAGICK_FAILED}" \
  "${ENGINE_POOL_LIBVIPS_PUSH_TOKEN:-}|libvips|${LIBVIPS_N}|${LIBVIPS_MEDIAN}|${LIBVIPS_P95}|${LIBVIPS_WAITING}|${LIBVIPS_ACTIVE}|${LIBVIPS_FAILED}"; do
  IFS='|' read -r token engine n median p95 waiting active failed <<< "$tup"

  # Failure-delta detection: compare against state file from prior run.
  state_file="${STATE_DIR}/${engine}.failed"
  prev_failed=0
  have_prev=0
  if [[ -f "$state_file" ]]; then
    prev_failed=$(cat "$state_file" 2>/dev/null || echo 0)
    have_prev=1
  fi
  echo "$failed" > "$state_file"

  status="up"
  alarm_msg=""
  if (( have_prev )) && (( failed > prev_failed )); then
    delta=$(( failed - prev_failed ))
    status="down"
    alarm_msg="+${delta}+failed+since+last+poll+(now+${failed})"
  fi

  if [[ -n "$alarm_msg" ]]; then
    msg="$alarm_msg+wait=${waiting}+active=${active}+median=${median}ms"
  else
    msg="n=${n}+median=${median}ms+p95=${p95}ms+wait=${waiting}+active=${active}+failed=${failed}"
  fi
  push "$token" "$engine" "$status" "$median" "$msg"
done

exit 0
