#!/usr/bin/env bash
# Idempotently inject the Umami snippet before </head> in a static HTML file.
# Usage: inject-snippet.sh <website_id> <path-to-html-file>
# Run on Netcup against the site's served HTML (e.g. index.html / head template).
set -euo pipefail

WID="${1:?website_id required}"
FILE="${2:?html file path required}"
MARKER="umami-analytics-hub"

[ -f "$FILE" ] || { echo "no such file: $FILE" >&2; exit 1; }

if grep -q "$MARKER" "$FILE"; then
  echo "already wired: $FILE"; exit 0
fi
grep -qi "</head>" "$FILE" || { echo "no </head> in $FILE — inject manually" >&2; exit 2; }

SNIPPET="<script defer src=\"https://analytics.rspace.online/collect.js\" data-website-id=\"${WID}\" data-${MARKER}></script>"
# insert before the first </head> (case-insensitive)
cp "$FILE" "$FILE.bak-analytics"
perl -0pi -e "s{(</head>)}{${SNIPPET}\n\$1}i if !\$done++" "$FILE"
echo "injected -> $FILE (backup: $FILE.bak-analytics)"
