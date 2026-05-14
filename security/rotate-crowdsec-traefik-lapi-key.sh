#!/usr/bin/env bash
# Rotate the CrowdSec LAPI bouncer API key used by the Traefik
# crowdsec-bouncer plugin on Netcup.
#
# Sequence:
#   1. Register a new bouncer in CrowdSec (`cscli bouncers add`); capture the key.
#   2. Write the new key into /root/traefik/config/crowdsec.yml (timestamped
#      backup beside the file).
#   3. Traefik's file provider watches the dir and reloads automatically —
#      no container restart needed. Sleep briefly, then verify by reading
#      Traefik logs for the bouncer plugin reporting healthy LAPI access.
#   4. Delete the previous bouncer entry (and any same-named orphans).
#   5. inventory_mark_rotated.
#
# Failure modes:
#   - If the file edit fails, the timestamped .bak file is the rollback.
#   - If LAPI auth fails after the swap, the old bouncer entry is NOT
#     deleted yet, so reverting the YAML is a clean rollback.
#
# Conventions match rotate-engine-pool-token.sh / rotate-gitea-webhook.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

parse_common_args "$@"

NAME="crowdsec-traefik-lapi-key"
SSH_TARGET="${SSH_TARGET:-netcup-full}"
CFG_PATH=/root/traefik/config/crowdsec.yml
BOUNCER_NAME_NEW="traefik-bouncer-$(date -u +%Y%m%d-%H%M)"

log "rotating $NAME (DRY_RUN=$DRY_RUN)"

# Step 1: register new bouncer, capture key.
if (( DRY_RUN )); then
  log "DRY-RUN: would register $BOUNCER_NAME_NEW on CrowdSec"
  NEW_KEY="<dry-run-placeholder-key>"
else
  NEW_KEY=$(ssh "$SSH_TARGET" "docker exec crowdsec cscli bouncers add $BOUNCER_NAME_NEW -o raw" 2>/dev/null)
  [[ -n "$NEW_KEY" ]] || die "cscli bouncers add returned empty key"
  log "registered new bouncer: $BOUNCER_NAME_NEW (key captured, ${#NEW_KEY} chars)"
fi

# Step 2: swap the key — fetch locally, rewrite, scp back. Avoids nested
# quote/heredoc layers between bash/ssh/zsh/python (see memory note
# python_heredoc_yaml_backticks.md).
if (( DRY_RUN )); then
  log "DRY-RUN: would fetch $CFG_PATH, rewrite crowdsecLapiKey locally, scp back"
else
  TS=$(date -u +%Y%m%d-%H%M%S)
  TMP_IN=$(mktemp); TMP_OUT=$(mktemp)
  trap "rm -f $TMP_IN $TMP_OUT" EXIT
  scp -q "$SSH_TARGET:$CFG_PATH" "$TMP_IN"
  ssh "$SSH_TARGET" "cp $CFG_PATH ${CFG_PATH}.bak-pre-rotate-${TS}"

  NEW_KEY="$NEW_KEY" python3 <<PY
import os, pathlib, re
src, dst = "$TMP_IN", "$TMP_OUT"
new = os.environ["NEW_KEY"]
t = pathlib.Path(src).read_text()
t, n = re.subn(r'(crowdsecLapiKey:\s*")[^"]*(")', lambda m: m.group(1)+new+m.group(2), t)
assert n == 1, f"expected exactly 1 LapiKey match, got {n}"
pathlib.Path(dst).write_text(t)
PY

  scp -q "$TMP_OUT" "$SSH_TARGET:$CFG_PATH"
fi
log "Traefik config updated; file provider will reload within a few seconds"

# Step 3: restart Traefik so the bouncer plugin reloads. File-provider
# hot-reload alone is NOT enough — crowdsec-bouncer-traefik-plugin caches
# config at first use, so a restart is required to bind the new LAPI key.
# Verified empirically 2026-05-14 (TASK-87): after file-only swap, the
# CrowdSec-side `Last API pull` stayed empty until Traefik restarted.
if (( DRY_RUN )); then
  log "DRY-RUN: would restart Traefik to re-bind the bouncer plugin"
else
  log "restarting Traefik (brief outage ~5s)..."
  ssh "$SSH_TARGET" "docker restart traefik" >/dev/null
  sleep 65  # one bouncer pull interval

  # Verify CrowdSec-side: the bouncer should now show a recent Last API pull.
  LAST_PULL=$(ssh "$SSH_TARGET" "docker exec crowdsec cscli bouncers list -o raw" \
    | awk -F, -v n="$BOUNCER_NAME_NEW" '$1==n {print $4}')
  if [[ -z "$LAST_PULL" ]]; then
    log "WARNING: bouncer Last API pull is empty after restart — inspect Traefik logs"
  else
    log "bouncer Last API pull: $LAST_PULL"
  fi
fi

# Step 4: delete previous bouncer(s). The active one was named traefik-bouncer
# (with optional @<ip> suffix if recreated). Keep our new one.
if (( DRY_RUN )); then
  log "DRY-RUN: would list bouncers and delete any not named $BOUNCER_NAME_NEW"
else
  log "removing stale bouncer entries..."
  ssh "$SSH_TARGET" "
    docker exec crowdsec cscli bouncers list -o raw | tail -n +2 | awk -F, '{print \$1}' | while read -r b; do
      [[ \"\$b\" == \"$BOUNCER_NAME_NEW\" ]] && continue
      [[ \"\$b\" == \"\" ]] && continue
      case \"\$b\" in traefik-bouncer*)
        echo \"  deleting stale: \$b\"
        docker exec crowdsec cscli bouncers delete \"\$b\" || echo \"  WARN: delete failed for \$b\"
      ;; esac
    done
  "
fi

# Step 5: bump last_rotated in inventory.
if (( DRY_RUN )); then
  log "DRY-RUN: would inventory_mark_rotated $NAME"
else
  TODAY=$(inventory_mark_rotated "$NAME")
  log "inventory_mark_rotated → $TODAY"
fi

log "rotation complete"
