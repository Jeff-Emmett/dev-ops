# Fish shell configuration

# Auto-attach to tmux session
function ta
    tmux attach -t main 2>/dev/null; or tmux new -s main
end

# Abbreviations (expand on space, like aliases but better)
abbr -a ll 'ls -la'
abbr -a .. 'cd ..'
abbr -a ... 'cd ../..'
fish_add_path ~/bin

# Auto-enter claude-dev container on interactive login
if status is-interactive; and not set -q INSIDE_CLAUDE_CONTAINER
    set -l CONTAINER claude-dev
    if docker inspect $CONTAINER --format '{{.State.Running}}' 2>/dev/null | grep -q true
        exec docker exec -it -e TERM=$TERM -e INSIDE_CLAUDE_CONTAINER=1 $CONTAINER fish
    else
        echo "Starting claude-dev container..."
        cd /opt/apps/claude-dev; and docker compose up -d; and sleep 2
        exec docker exec -it -e TERM=$TERM -e INSIDE_CLAUDE_CONTAINER=1 $CONTAINER fish
    end
end
