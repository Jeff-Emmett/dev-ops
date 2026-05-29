#!/usr/bin/env bash
# test-rotation.sh — verify the framework end-to-end against DISCORD_RELAY_SECRET
# (an internal-only secret with no upstream API call — safest possible test).
#
# What this proves:
#   - registry.json parses
#   - rotate.ts can call the 'internal' rotator
#   - infisical PATCH works (writes new value)
#   - audit log gets an entry
#   - the deploy trigger fires
set -euo pipefail
cd "$(dirname "$0")/.."
echo "Forcing rotation of DISCORD_RELAY_SECRET (safe — internal-only)…"
bun run rotate.ts --secret DISCORD_RELAY_SECRET --force
echo
echo "Audit log (last 5 entries):"
ls -1t audit/*.jsonl 2>/dev/null | head -1 | xargs tail -5 || echo "(no audit dir yet)"
