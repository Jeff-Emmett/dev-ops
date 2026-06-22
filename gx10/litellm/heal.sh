#!/bin/sh
# Self-heal watchdog for gx10-litellm. Runs forever inside the
# gx10-litellm-watchdog container (docker:cli + docker.sock). Heals the
# three failure modes seen in prod:
#   1. container stopped/exited and didn't auto-restart      -> docker start
#   2. healthcheck unhealthy                                 -> docker restart
#   3. host port 4001 unpublished (the tailscale-bind-on-boot race:
#      docker started litellm before tailscale0 had 100.64.0.5, so the
#      published port silently never bound)                  -> docker restart
# A plain start/restart is enough — verified that restart re-binds the
# host port once tailscale0 is up. "missing" (container removed) needs a
# compose recreate, which is out of scope for the watchdog; it logs loudly.
set -u
TARGET="${TARGET:-gx10-litellm}"
INTERVAL="${INTERVAL:-30}"
echo "[heal] watchdog up; target=$TARGET interval=${INTERVAL}s"
while true; do
  st=$(docker inspect -f '{{.State.Status}}' "$TARGET" 2>/dev/null || echo missing)
  hl=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$TARGET" 2>/dev/null || echo none)
  pub=$(docker inspect -f '{{json .NetworkSettings.Ports}}' "$TARGET" 2>/dev/null | grep -c 4001 || true)
  if [ "$st" = "missing" ]; then
    echo "[heal] $(date -u +%FT%TZ) $TARGET MISSING — recreate manually: cd ~/gx10-litellm && docker compose up -d"
  elif [ "$st" != "running" ]; then
    echo "[heal] $(date -u +%FT%TZ) status=$st -> docker start"; docker start "$TARGET" || true
  elif [ "$hl" = "unhealthy" ]; then
    echo "[heal] $(date -u +%FT%TZ) health=unhealthy -> docker restart"; docker restart "$TARGET" || true
  elif [ "$pub" = "0" ]; then
    echo "[heal] $(date -u +%FT%TZ) host port 4001 unpublished (bind race) -> docker restart"; docker restart "$TARGET" || true
  fi
  sleep "$INTERVAL"
done
