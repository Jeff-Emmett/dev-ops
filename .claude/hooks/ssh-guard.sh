#!/usr/bin/env bash
# PreToolUse hook: warns before destructive SSH commands to production
# Input: JSON on stdin with tool_name, tool_input
# Exit 0 = allow, exit 2 = block

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Skip if not an SSH command
if ! echo "$COMMAND" | grep -qE '^ssh|netcup|netcup-full'; then
  exit 0
fi

# Block destructive patterns on production server
DESTRUCTIVE_PATTERNS='rm -rf|docker system prune|docker volume prune|DROP TABLE|DROP DATABASE|systemctl stop|shutdown|reboot|dd if=|mkfs\.|format '

if echo "$COMMAND" | grep -qEi "$DESTRUCTIVE_PATTERNS"; then
  echo "BLOCKED: Destructive command detected targeting production server."
  echo "Command: $COMMAND"
  echo "Review and run manually if intended."
  exit 2
fi

exit 0
