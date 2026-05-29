#!/usr/bin/env bash
# install-cron.sh — install a systemd timer that runs rotate.ts daily at 3am.
#
# Run as the user that owns ~/.secrets/ (i.e. jeffe), NOT as root.
set -euo pipefail

UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"

HERE="$(cd "$(dirname "$0")/.." && pwd)"

cat > "$UNIT_DIR/secret-rotation.service" <<EOF
[Unit]
Description=Custom secret rotation cron — rotate due secrets and write to Infisical
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=${HERE}
ExecStart=$(command -v bun) run rotate.ts
StandardOutput=journal
StandardError=journal
EOF

cat > "$UNIT_DIR/secret-rotation.timer" <<EOF
[Unit]
Description=Daily secret-rotation timer

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
RandomizedDelaySec=600

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now secret-rotation.timer

echo "Installed. Next run:"
systemctl --user list-timers secret-rotation.timer --no-pager
