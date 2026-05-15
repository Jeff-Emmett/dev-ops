#!/usr/bin/env bash
# Read secrets-inventory.yaml, compute which secrets are within
# WARN_DAYS of (last_rotated + cadence_days), and email Jeff.
#
# Designed to run weekly under systemd timer on Netcup. Idempotent — sending
# the same digest twice in the same week is fine; it's a single low-volume
# email.
#
# Email path is the same Mailcow → postfix sendmail trick used elsewhere
# (see ~/.claude/CLAUDE.md). Runs locally on Netcup so it can pipe directly.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INVENTORY="${INVENTORY:-${SCRIPT_DIR}/secrets-inventory.yaml}"
WARN_DAYS="${WARN_DAYS:-14}"
RECIPIENT="${RECIPIENT:-jeffemmett@gmail.com}"
SENDER="${SENDER:-claude@jeffemmett.com}"
POSTFIX_CONTAINER="${POSTFIX_CONTAINER:-mailcowdockerized-postfix-mailcow-1}"

# Compute the digest body (Markdown-friendly plain text)
BODY=$(python3 - "$INVENTORY" "$WARN_DAYS" <<'PY'
import sys, datetime, yaml
inv_path, warn_days = sys.argv[1], int(sys.argv[2])
today = datetime.date.today()
with open(inv_path) as f:
    data = yaml.safe_load(f)

due_now, due_soon, ok = [], [], []
for s in data.get('secrets', []):
    name = s['name']
    cadence = int(s.get('cadence_days', 365))
    last = s.get('last_rotated')
    if not last:
        due_now.append((name, 'no last_rotated set', cadence, '-'))
        continue
    last_d = last if isinstance(last, datetime.date) else datetime.date.fromisoformat(str(last))
    next_due = last_d + datetime.timedelta(days=cadence)
    days_left = (next_due - today).days
    mode = s.get('rotation', {}).get('mode', '?')
    target = s.get('rotation', {}).get('script') or s.get('rotation', {}).get('runbook') or '-'
    row = (name, last_d.isoformat(), cadence, days_left, mode, target)
    if days_left < 0:
        due_now.append(row)
    elif days_left <= warn_days:
        due_soon.append(row)
    else:
        ok.append(row)

def fmt(rows):
    out = []
    for r in rows:
        if len(r) == 6:
            n, last, cad, days, mode, tgt = r
            sign = f"+{days}" if days >= 0 else str(days)
            out.append(f"  - {n:<30} last={last} cadence={cad}d days_left={sign:<5} {mode:<6} {tgt}")
        else:
            out.append(f"  - {r[0]} ({r[1]})")
    return '\n'.join(out) if out else '  (none)'

lines = []
if due_now:
    lines.append('## OVERDUE')
    lines.append(fmt(due_now))
if due_soon:
    lines.append(f'\n## Due within {warn_days} days')
    lines.append(fmt(due_soon))
if not (due_now or due_soon):
    print('NO_ACTION_NEEDED')
    sys.exit(0)
lines.append(f'\n## All other secrets ({len(ok)})')
lines.append(fmt(ok))
print('\n'.join(lines))
PY
)

if [[ "$BODY" == "NO_ACTION_NEEDED" ]]; then
  echo "no rotations due within ${WARN_DAYS} days; not sending email"
  exit 0
fi

# Count only entries in OVERDUE + "Due within Nd" sections (everything
# before the "All other secrets" heading), not the full inventory listing.
ACTION_COUNT=$(printf '%s\n' "$BODY" | awk '
  /^## All other secrets/ { exit }
  /^  - / { n++ }
  END { print n+0 }
')
SUBJECT="[secrets] ${ACTION_COUNT} secret(s) need rotation attention"

# Send via the postfix sendmail in mailcow (same path as backlog notifications)
{
  printf 'From: Claude <%s>\n' "$SENDER"
  printf 'To: %s\n' "$RECIPIENT"
  printf 'Subject: %s\n' "$SUBJECT"
  printf 'Content-Type: text/plain; charset=utf-8\n'
  printf '\n'
  printf 'Secret rotation digest for %s\n' "$(date -u +%Y-%m-%d)"
  printf '%s\n\n' "----------------------------------------"
  printf '%s\n\n' "$BODY"
  printf 'Inventory: dev-ops/security/secrets-inventory.yaml\n'
  printf 'Run: ./security/rotate-<name>.sh   or  follow ./security/runbook-<name>.md\n'
} | docker exec -i "$POSTFIX_CONTAINER" sendmail -f "$SENDER" "$RECIPIENT"

echo "digest sent: ${SUBJECT}"
