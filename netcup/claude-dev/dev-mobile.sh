#!/usr/bin/env bash
# Mobile development entry point
# Ensures claude-dev container is running, then drops into tmux inside it.
# Usage: dev-mobile [project-dir]
#
# Called by: mosh netcup -- dev-mobile [dir]
# From Termux: mosh netcup -- dev-mobile /opt/apps/canvas-website

CONTAINER="claude-dev"
SESSION="dev"
PROJECT_DIR="${1:-/opt/apps}"

# Ensure the container is running
if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
    echo "Starting claude-dev container..."
    cd /opt/apps/claude-dev && docker compose up -d
    sleep 2
fi

# Exec into the container's tmux (create or attach)
exec docker exec -it -e TERM=xterm-256color -w "$PROJECT_DIR" "$CONTAINER" \
    tmux new-session -A -s "$SESSION"
