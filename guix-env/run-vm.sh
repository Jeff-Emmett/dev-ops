#!/usr/bin/env bash
# Boot the Guix desktop VM: KVM-accelerated, 4 GB RAM, GTK display (WSLg).
# Rebuilds from config-vm.scm if anything changed, else launches instantly.
#
#   ./run-vm.sh                 # boot the desktop
#   ./run-vm.sh -m 6144         # extra args pass straight to QEMU
set -euo pipefail
export PATH="$HOME/.config/guix/current/bin:$PATH"
CONFIG="$(cd "$(dirname "$0")" && pwd)/config-vm.scm"
SCRIPT="$(guix system vm "$CONFIG")"     # prints the (cached) run-vm.sh path
exec "$SCRIPT" -m 4096 -display gtk "$@"
