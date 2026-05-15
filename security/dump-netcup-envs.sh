#!/usr/bin/env bash
# Regenerate dev-ops/security/netcup-service-envs.md from the live state
# on Netcup. Lists every .env file under /opt with its KEY NAMES ONLY
# (no values) and classifies each as Infisical-only / mixed / plain.
#
# Run periodically (quarterly?) to keep the index honest. Pair with the
# `netcup-service-envs` inventory meta-entry which carries the cadence.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_TARGET="${SSH_TARGET:-netcup-full}"
OUT="${SCRIPT_DIR}/netcup-service-envs.md"

TMP=$(mktemp)
trap "rm -f $TMP" EXIT

ssh "$SSH_TARGET" '
  for f in $(find /opt/apps /opt /opt/services /opt/websites -maxdepth 4 -name ".env" -type f 2>/dev/null \
              | sort -u | grep -vE "/(archive|\.bak|zombie|.bak\.)"); do
    KEYS=$(grep -E "^[A-Z_][A-Z0-9_]*=" "$f" 2>/dev/null | sed "s/=.*//" | tr "\n" "," | sed "s/,$//")
    echo "$f|$KEYS"
  done
' > "$TMP"

python3 - "$TMP" "$OUT" <<'PY'
import sys, datetime
from pathlib import Path
tsv_path, out_path = sys.argv[1], sys.argv[2]
rows = [l.split("|", 1) for l in Path(tsv_path).read_text().strip().splitlines() if "|" in l]

def classify(keys: str) -> str:
    if not keys.strip(): return "empty"
    s = set(keys.split(","))
    infi = any(k.startswith("INFISICAL_") for k in s)
    others = [k for k in s if not k.startswith("INFISICAL_")]
    if infi and not others: return "infisical-only"
    if infi: return "mixed (Infisical + plain)"
    return "plain"

today = datetime.date.today().isoformat()
out = [
    "# Netcup service .env index",
    "",
    f"Auto-generated {today} via `dev-ops/security/dump-netcup-envs.sh`.",
    "Lists every `.env` file on Netcup under `/opt/`, classified by whether",
    "it uses Infisical bootstrap or plain secrets. KEY NAMES ONLY — no values.",
    "",
    "Entries in `secrets-inventory.yaml` carry the rotation cadence;",
    "this doc carries the structural overview.",
    "",
    "| Path | Type | Keys |",
    "|------|------|------|",
]
for path, keys in sorted(rows):
    t = classify(keys)
    short = (keys[:80] + "...") if len(keys) > 80 else keys
    out.append(f"| `{path}` | {t} | `{short}` |")

Path(out_path).write_text("\n".join(out) + "\n")
print(f"wrote {len(rows)} rows to {out_path}")
PY
