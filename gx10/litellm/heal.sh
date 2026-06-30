#!/bin/sh
# Self-heal watchdog for gx10-litellm. Runs forever inside the
# gx10-litellm-watchdog container (docker:cli ships `docker compose` +
# docker.sock). Heals the failure modes seen in prod:
#   1. container stopped/exited and didn't auto-restart      -> docker start
#   2. healthcheck unhealthy                                 -> docker restart
#   3. host port 4001 unpublished (the tailscale-bind-on-boot race:
#      docker started litellm before tailscale0 had 100.64.0.5, so the
#      IP-specific published port silently never bound)      -> compose recreate
#
# IMPORTANT: a plain `docker restart` does NOT republish a port — it reuses
# the existing container's (failed) port plumbing, so it loops forever and
# never heals the bind race. Only recreating the container re-runs the
# publish step. The project dir is bind-mounted at its real host path so
# `docker compose` resolves the ./config.yaml / .env binds to identical
# host paths (docker-in-docker relative-path requirement).
set -u
TARGET="${TARGET:-gx10-litellm}"
INTERVAL="${INTERVAL:-30}"
PROJECT_DIR="${PROJECT_DIR:-/home/mycopunk/gx10-litellm}"
recreate() { cd "$PROJECT_DIR" 2>/dev/null && docker compose up -d --force-recreate "$TARGET"; }
echo "[heal] watchdog up; target=$TARGET interval=${INTERVAL}s project=$PROJECT_DIR"
while true; do
  st=$(docker inspect -f '{{.State.Status}}' "$TARGET" 2>/dev/null || echo missing)
  hl=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$TARGET" 2>/dev/null || echo none)
  pub=$(docker inspect -f '{{json .NetworkSettings.Ports}}' "$TARGET" 2>/dev/null | grep -c 4001 || true)
  if [ "$st" = "missing" ]; then
    echo "[heal] $(date -u +%FT%TZ) $TARGET MISSING -> compose recreate"; recreate || true
  elif [ "$st" != "running" ]; then
    echo "[heal] $(date -u +%FT%TZ) status=$st -> docker start"; docker start "$TARGET" || true
  elif [ "$hl" = "unhealthy" ]; then
    echo "[heal] $(date -u +%FT%TZ) health=unhealthy -> docker restart"; docker restart "$TARGET" || true
  elif [ "$pub" = "0" ]; then
    echo "[heal] $(date -u +%FT%TZ) host port 4001 unpublished (bind race) -> compose recreate"; recreate || true
  fi
  sleep "$INTERVAL"
done
