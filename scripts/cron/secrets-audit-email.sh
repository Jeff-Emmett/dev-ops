#!/usr/bin/env bash
# Monthly: render secrets-rotation PDF audit and email to Jeff.
#
# Complements the existing weekly text digest (rotation-digest.timer); this
# is a richer snapshot suitable for retention and audit review.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RECIPIENT="${RECIPIENT:-jeffemmett@gmail.com}"

PDF="$(mktemp -t secrets-audit-XXXXXX.pdf)"
trap 'rm -f "$PDF"' EXIT

python3 "${REPO}/security/audit-report.py" --output "$PDF"

MONTH="$(date +%Y-%m)"
python3 "${REPO}/scripts/mail_helper.py" \
  --to "$RECIPIENT" \
  --subject "Secrets rotation audit — ${MONTH}" \
  --body "Automated monthly secrets-rotation snapshot.

Inventory source: security/secrets-inventory.yaml
Companion to the weekly text digest from rotation-digest.timer (this PDF
is the richer record-keeping artifact)." \
  --attach "$PDF"
