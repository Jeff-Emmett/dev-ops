#!/bin/bash
# PreToolUse hook: blocks destructive SSH commands to production
# Input: JSON on stdin with tool_name, tool_input
# Exit 0 = allow, exit 2 = block

set -euo pipefail

# Read input from stdin
input=$(cat)

# Extract command
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Skip if no command
if [ -z "$command" ]; then
  exit 0
fi

# Skip if not an SSH command targeting our server
if ! [[ "$command" == *"ssh"* ]] && ! [[ "$command" == *"netcup"* ]]; then
  exit 0
fi

# Block destructive patterns on production server
if [[ "$command" == *"rm -rf"* ]] || [[ "$command" == *"rm -fr"* ]]; then
  echo '{"hookSpecificOutput": {"permissionDecision": "deny"}, "systemMessage": "BLOCKED: rm -rf targeting production server. Run manually if intended."}' >&2
  exit 2
fi

if [[ "$command" == *"docker system prune"* ]] || [[ "$command" == *"docker volume prune"* ]]; then
  echo '{"hookSpecificOutput": {"permissionDecision": "deny"}, "systemMessage": "BLOCKED: Docker prune targeting production server. Run manually if intended."}' >&2
  exit 2
fi

if [[ "$command" == *"DROP TABLE"* ]] || [[ "$command" == *"DROP DATABASE"* ]]; then
  echo '{"hookSpecificOutput": {"permissionDecision": "deny"}, "systemMessage": "BLOCKED: DROP statement targeting production database. Run manually if intended."}' >&2
  exit 2
fi

if [[ "$command" == *"systemctl stop"* ]] || [[ "$command" == *"shutdown"* ]] || [[ "$command" == *"reboot"* ]]; then
  echo '{"hookSpecificOutput": {"permissionDecision": "deny"}, "systemMessage": "BLOCKED: System stop/reboot targeting production server. Run manually if intended."}' >&2
  exit 2
fi

if [[ "$command" == *"dd if="* ]] || [[ "$command" == *"mkfs"* ]]; then
  echo '{"hookSpecificOutput": {"permissionDecision": "deny"}, "systemMessage": "BLOCKED: Disk operation targeting production server. Run manually if intended."}' >&2
  exit 2
fi

# Allow the operation
exit 0
