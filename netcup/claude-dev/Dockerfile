FROM node:20-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    fish \
    tmux \
    openssh-client \
    curl \
    jq \
    less \
    vim-tiny \
    fzf \
    ca-certificates \
    gnupg \
    locales \
    keepassxc \
    && rm -rf /var/lib/apt/lists/*

# Generate UTF-8 locale (needed for tmux/mosh)
RUN sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen && locale-gen

# Install Docker CLI + Compose plugin (CLI only, no daemon)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Create dev user matching deploy (uid 1001) on host
RUN groupadd -g 1001 dev \
    && useradd -u 1001 -g 1001 -m -s /usr/bin/fish dev

# Create docker group matching host GID and add dev user
RUN groupadd -g 990 docker && usermod -aG docker dev

# Directories for tmux, claude, fish
RUN mkdir -p /home/dev/.claude \
    /home/dev/.config/fish \
    /home/dev/.config/tmux \
    /home/dev/.local/share/fish \
    /home/dev/Sync/tmux-resurrect \
    && chown -R dev:dev /home/dev

# Symlink .claude.json into the persistent .claude/ volume
RUN ln -sf /home/dev/.claude/.claude.json /home/dev/.claude.json

# Git config for the dev user
RUN printf '[user]\n\tname = Jeff Emmett\n\temail = jeff@jeffemmett.com\n[core]\n\tsshCommand = ssh -i /home/dev/.ssh/gitea_ed25519 -o UserKnownHostsFile=/home/dev/.claude/known_hosts\n[safe]\n\tdirectory = *\n' > /home/dev/.gitconfig \
    && chown dev:dev /home/dev/.gitconfig

# System SSH config: writable known_hosts (since ~/.ssh is mounted read-only)
RUN mkdir -p /etc/ssh/ssh_config.d \
    && printf 'UserKnownHostsFile /home/dev/.claude/known_hosts\nStrictHostKeyChecking accept-new\n' > /etc/ssh/ssh_config.d/container.conf

# tmux super_fingers helper scripts (open-url, open-file)
COPY --chown=dev:dev open-url open-file /usr/local/bin/
RUN chmod +x /usr/local/bin/open-url /usr/local/bin/open-file

# Entrypoint script (assembles tmux/fish config from mounts)
COPY --chown=dev:dev entrypoint.sh /home/dev/entrypoint.sh
RUN chmod +x /home/dev/entrypoint.sh

USER dev
WORKDIR /opt

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV TERM=xterm-256color
ENV SHELL=/usr/bin/fish
ENV HOME=/home/dev
