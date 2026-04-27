#!/usr/bin/env bash
# Shared helpers for rotation scripts. `source` this from rotate-*.sh.
#
# Provides:
#   inventory_get <name> <field>   — read a top-level field from a secret entry
#   inventory_mark_rotated <name>  — atomically update last_rotated to today
#   log <msg>                      — timestamped stderr line
#   die <msg>                      — log and exit 1
#   run <cmd...>                   — echo if DRY_RUN=1, else execute

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${INVENTORY:-${SCRIPT_DIR}/secrets-inventory.yaml}"

DRY_RUN=0

log()  { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*" >&2; }
die()  { log "ERROR: $*"; exit 1; }
run()  {
  if (( DRY_RUN )); then
    log "DRY-RUN: $*"
  else
    "$@"
  fi
}

# Read a scalar field from the secrets-inventory entry with name=<arg1>.
# Path examples: "cadence_days", "location.path", "rotation.script".
inventory_get() {
  local name="$1" field="$2"
  python3 - "$INVENTORY" "$name" "$field" <<'PY'
import sys, yaml
path, name, field = sys.argv[1:]
with open(path) as f:
    data = yaml.safe_load(f)
for s in data.get('secrets', []):
    if s.get('name') == name:
        obj = s
        for part in field.split('.'):
            if obj is None:
                break
            obj = obj.get(part) if isinstance(obj, dict) else None
        print('' if obj is None else obj)
        sys.exit(0)
print(f'ERR: secret {name!r} not found in inventory', file=sys.stderr)
sys.exit(2)
PY
}

# Atomically update the last_rotated field for a given secret to today (UTC).
inventory_mark_rotated() {
  local name="$1"
  python3 - "$INVENTORY" "$name" <<'PY'
import sys, datetime, yaml, tempfile, os, shutil
path, name = sys.argv[1:]
today = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
with open(path) as f:
    text = f.read()
# YAML round-trip via ruamel would preserve comments; fall back to line-by-line
# substitution to keep this dependency-free.
out, in_target, found = [], False, False
for line in text.splitlines(keepends=True):
    stripped = line.strip()
    if stripped.startswith('- name:'):
        in_target = (stripped.split(':',1)[1].strip() == name)
    if in_target and stripped.startswith('last_rotated:'):
        indent = line[:len(line) - len(line.lstrip())]
        out.append(f"{indent}last_rotated: {today}\n")
        found = True
    else:
        out.append(line)
if not found:
    print(f'ERR: last_rotated field not found for {name!r}', file=sys.stderr)
    sys.exit(2)
tmp = path + '.tmp'
with open(tmp, 'w') as f:
    f.writelines(out)
os.replace(tmp, path)
print(today)
PY
}

# Argparse: any rotate-*.sh sources this and gets --dry-run / --help support
# automatically.
parse_common_args() {
  while (( $# > 0 )); do
    case "$1" in
      --dry-run|-n) DRY_RUN=1; shift ;;
      --help|-h)
        cat <<USAGE
Usage: $(basename "$0") [--dry-run]

  --dry-run, -n   show actions without executing
  --help, -h      this help
USAGE
        exit 0
        ;;
      *) die "unknown flag: $1" ;;
    esac
  done
}
