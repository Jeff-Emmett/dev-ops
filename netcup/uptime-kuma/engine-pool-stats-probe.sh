#!/usr/bin/env bash
# Engine pool latency probe for Uptime Kuma.
#
# Runs every 5 min on Netcup. Pulls morpheus-engine-pool's /stats
# endpoint and pushes per-engine median_ms (as the heartbeat ping
# value) plus p95 + sample count (as the message) to four push
# monitors — one per engine.
#
# Status:
#   up   — engine pool reachable, regardless of whether the engine
#          had samples in the scan window. n=0 is normal for idle
#          engines (whisper/libvips on quiet days). The ping value
#          becomes 0 in that case so the latency chart degrades
#          gracefully without false alarm.
#   down — engine pool unreachable. All four monitors trip together
#          so alerts fire only once.
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

# Fetch /stats from inside the engine-pool-server container — its 8000
# port isn't published to the host, but `docker exec` inside the
# container reaches localhost:8000 directly.
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
  # Engine pool unreachable — alarm all four monitors at once.
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

# Parse all four engines in one Python pass, emit shell vars.
eval "$(printf '%s' "$STATS_JSON" | python3 -c '
import sys, json
d = json.load(sys.stdin)["engines"]
for e in ("ffmpeg", "whisper", "imagemagick", "libvips"):
    bucket = d.get(e, {})
    n = bucket.get("n") or 0
    median = bucket.get("median_ms") or 0
    p95 = bucket.get("p95_ms") or 0
    print(f"{e.upper()}_N={n}")
    print(f"{e.upper()}_MEDIAN={median}")
    print(f"{e.upper()}_P95={p95}")
' )"

for tup in \
  "${ENGINE_POOL_FFMPEG_PUSH_TOKEN:-}|ffmpeg|${FFMPEG_N}|${FFMPEG_MEDIAN}|${FFMPEG_P95}" \
  "${ENGINE_POOL_WHISPER_PUSH_TOKEN:-}|whisper|${WHISPER_N}|${WHISPER_MEDIAN}|${WHISPER_P95}" \
  "${ENGINE_POOL_IMAGEMAGICK_PUSH_TOKEN:-}|imagemagick|${IMAGEMAGICK_N}|${IMAGEMAGICK_MEDIAN}|${IMAGEMAGICK_P95}" \
  "${ENGINE_POOL_LIBVIPS_PUSH_TOKEN:-}|libvips|${LIBVIPS_N}|${LIBVIPS_MEDIAN}|${LIBVIPS_P95}"; do
  IFS='|' read -r token engine n median p95 <<< "$tup"
  msg="n=${n}+median=${median}ms+p95=${p95}ms"
  push "$token" "$engine" "up" "$median" "$msg"
done

exit 0
