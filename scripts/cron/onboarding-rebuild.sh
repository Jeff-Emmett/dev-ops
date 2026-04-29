#!/usr/bin/env bash
# Monthly: rebuild the dev-ops onboarding handbook PDF.
#
# Output: /opt/dev-ops/docs/onboarding.pdf  (single canonical artifact;
# overwritten in place so links to it never go stale).
#
# Stays local — does not email. The handbook is reference material, not a
# digest, so emailing the same 56-page PDF every month would just be noise.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUTPUT="${REPO}/docs/onboarding.pdf"

mkdir -p "$(dirname "$OUTPUT")"
python3 "${REPO}/scripts/build-onboarding.py" --output "$OUTPUT"
echo "onboarding handbook rebuilt: $OUTPUT ($(stat -c %s "$OUTPUT") bytes)"
