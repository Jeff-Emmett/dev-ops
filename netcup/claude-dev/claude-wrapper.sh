#!/usr/bin/env bash
# Wrapper to run Claude Code inside the containerized dev environment
# Replaces direct `claude` command on the host
# Usage: claude [args...]

CONTAINER="claude-dev"

# Check if container is running
if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
    echo "Starting claude-dev container..."
    cd /opt/apps/claude-dev && docker compose up -d
    sleep 2
fi

# Get current working directory and map it to container path
# /opt/websites/* and /opt/apps/* are mounted at the same paths
CWD="$(pwd)"
WORKDIR="/opt"

case "$CWD" in
    /opt/websites/*|/opt/apps/*)
        WORKDIR="$CWD"
        ;;
    /opt/*)
        WORKDIR="$CWD"
        ;;
esac

# Execute claude inside the container
exec docker exec -it -w "$WORKDIR" "$CONTAINER" claude "$@"
