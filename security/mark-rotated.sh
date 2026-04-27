#!/usr/bin/env bash
# Bump `last_rotated` for a secret without running an automated rotation.
# Used at the end of a manual runbook (or to record an out-of-band rotation).
#
# Usage:  ./mark-rotated.sh <secret-name>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

[[ $# -eq 1 ]] || die "Usage: $(basename "$0") <secret-name>"
name="$1"

# Confirm the secret exists in the inventory before touching the file
inventory_get "$name" "name" >/dev/null || die "no such secret: $name"

new_date=$(inventory_mark_rotated "$name")
log "marked $name as rotated on $new_date"
