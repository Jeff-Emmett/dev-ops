#!/usr/bin/env bash
# SessionStart hook: surfaces active backlog tasks and branch status
# Input: JSON on stdin with session_id
# Output: context text to stdout

# Consume stdin to prevent pipe issues
cat > /dev/null

echo "## Session Context"
echo ""

# Current branch and status
BRANCH=$(git -C /home/jeffe/Github/dev-ops branch --show-current 2>/dev/null || echo "unknown")
echo "**Branch:** \`$BRANCH\`"

# Active backlog tasks (In Progress)
if command -v backlog &>/dev/null; then
  IN_PROGRESS=$(backlog task list --plain --status "In Progress" 2>/dev/null || true)
  if [ -n "$IN_PROGRESS" ] && ! echo "$IN_PROGRESS" | grep -qi "no tasks"; then
    echo ""
    echo "### Active Tasks (In Progress)"
    echo "$IN_PROGRESS"
  fi

  # High priority To Do tasks
  HIGH_PRIORITY=$(backlog task list --plain --status "To Do" --priority high 2>/dev/null || true)
  if [ -n "$HIGH_PRIORITY" ] && ! echo "$HIGH_PRIORITY" | grep -qi "no tasks"; then
    echo ""
    echo "### High Priority (To Do)"
    echo "$HIGH_PRIORITY"
  fi
fi

# Check for stale in-progress tasks across all projects (limit to 10 files)
STALE_FILES=$(find /home/jeffe/Github/*/backlog/tasks/ -name "*.md" -mtime +3 2>/dev/null || true)
STALE_CHECK=""
COUNT=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ "$COUNT" -ge 5 ] && break
  if grep -q 'status: In Progress' "$f" 2>/dev/null; then
    TITLE=$(grep '^title:' "$f" 2>/dev/null | head -1 | sed 's/title: //')
    PROJ=$(echo "$f" | sed 's|/home/jeffe/Github/||;s|/backlog/.*||')
    STALE_CHECK="${STALE_CHECK}  - **${PROJ}**: ${TITLE} (stale >3 days)\n"
    COUNT=$((COUNT + 1))
  fi
done <<< "$STALE_FILES"

if [ -n "$STALE_CHECK" ]; then
  echo ""
  echo "### Stale Tasks (>3 days In Progress)"
  echo -e "$STALE_CHECK"
fi
