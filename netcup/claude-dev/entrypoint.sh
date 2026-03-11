#!/bin/bash
# Entrypoint: assemble tmux + fish config from read-only mounts
# Runs once on container start, then keeps container alive

# === Assemble tmux config ===
# Host config uses symlinks into /root/configuration/... which is inaccessible
# as uid 1001. We mount the sources at /mnt/* and re-link them here.

mkdir -p ~/.config/tmux

# Dotfiles (the files that were symlinks on the host)
for f in init.tmux keys.tmux mouse.tmux settings.tmux status.tmux serious.tmux.conf; do
    [ -f "/mnt/tmux-dotfiles/$f" ] && ln -sf "/mnt/tmux-dotfiles/$f" "$HOME/.config/tmux/$f"
done

# Local override files
[ -f "/mnt/tmux-local/plugins.tmux" ] && ln -sf "/mnt/tmux-local/plugins.tmux" "$HOME/.config/tmux/plugins.tmux"

# Plugins directory (pre-installed)
ln -sfn /mnt/tmux-plugins "$HOME/.config/tmux/plugins"

# Scripts directory
ln -sfn /mnt/tmux-scripts "$HOME/.config/tmux/scripts"

# super_fingers custom config
[ -f "/mnt/tmux-super-fingers/super_fingers_custom.py" ] && \
    ln -sf "/mnt/tmux-super-fingers/super_fingers_custom.py" "$HOME/.config/tmux/super_fingers_custom.py"

# TPM only resolves source-file ONE level deep, so we flatten the chain:
# Instead of .tmux.conf -> init.tmux -> plugins.tmux (2 levels, TPM misses plugins),
# we create a flat tmux.conf that sources plugins.tmux directly.
rm -f "$HOME/.config/tmux/tmux.conf"
cat > "$HOME/.config/tmux/tmux.conf" << 'TMUXCONF'
# Flattened config for TPM compatibility (sources plugins directly)
source-file ~/.config/tmux/plugins.tmux
source-file ~/.config/tmux/settings.tmux
source-file ~/.config/tmux/keys.tmux
source-file ~/.config/tmux/mouse.tmux
source-file ~/.config/tmux/status.tmux
set-option -g default-command "${SHELL}"
setw -g mode-keys vi
bind-key -T copy-mode-vi C-c send-keys -X copy-selection-and-cancel
TMUXCONF

# === Assemble fish config ===
mkdir -p ~/.config/fish
if [ -f /mnt/fish-config.fish ] && [ ! -f ~/.config/fish/config.fish ]; then
    # Copy (not link) so fish can write fish_variables next to it
    cp /mnt/fish-config.fish ~/.config/fish/config.fish
fi

# === Fetch KeePass master password from Infisical → tmpfs ===
if [ -f /opt/infisical/claude-ops.env ] && [ -n "${KEEPASS_MASTER_FILE:-}" ]; then
    source /opt/infisical/claude-ops.env
    # Use internal Docker network URL (external URL hits Cloudflare Access)
    INFISICAL_URL="${INFISICAL_INTERNAL_URL:-http://infisical:8080}"
    PROJECT_ID="5b64ec1b-5b67-4b48-8808-c2465c0be41a"

    TOKEN=$(curl -sf -X POST "$INFISICAL_URL/api/v1/auth/universal-auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"clientId\": \"$INFISICAL_CLIENT_ID\", \"clientSecret\": \"$INFISICAL_CLIENT_SECRET\"}" \
        | jq -r '.accessToken' 2>/dev/null)

    if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
        MASTER_PW=$(curl -sf "$INFISICAL_URL/api/v3/secrets/raw/KEEPASS_MASTER_PASSWORD?workspaceId=$PROJECT_ID&environment=prod&secretPath=/keepass" \
            -H "Authorization: Bearer $TOKEN" \
            | jq -r '.secret.secretValue' 2>/dev/null)

        if [ -n "$MASTER_PW" ] && [ "$MASTER_PW" != "null" ]; then
            echo "$MASTER_PW" > "$KEEPASS_MASTER_FILE"
            chmod 600 "$KEEPASS_MASTER_FILE"
            echo "[entrypoint] KeePass master password loaded to tmpfs"
        else
            echo "[entrypoint] WARNING: Could not fetch KeePass master password from Infisical" >&2
        fi
        unset MASTER_PW TOKEN
    else
        echo "[entrypoint] WARNING: Infisical auth failed" >&2
    fi
fi

# === Install Claude settings if mounted ===
if [ -f /mnt/claude-settings.json ]; then
    mkdir -p "$HOME/.claude"
    cp /mnt/claude-settings.json "$HOME/.claude/settings.json"
    echo "[entrypoint] Claude settings installed"
fi

# === Keep container running ===
exec sleep infinity
