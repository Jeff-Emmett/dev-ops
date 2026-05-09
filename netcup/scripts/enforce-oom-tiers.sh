#!/bin/bash
# Re-applies OOM score adjustments per service tier (TASK-HIGH.9).
# Run periodically by systemd timer to handle container restarts and new deploys.
#
# Tiers
#   0   infrastructure       must never die        oom_score_adj=-800
#   1   mission-critical     high availability     oom_score_adj=-100
#   2   production tolerable (default, untouched)  oom_score_adj= 0
#   3   sandbox/dev/staging  kill first            oom_score_adj=+500

set -uo pipefail

# Tier 0 — infrastructure (explicit list + name patterns)
TIER0_NAMES=(
  traefik
  infisical
  gitea
  uptime-kuma
  restic
  crowdsec
)
TIER0_PATTERN='^mailcowdockerized-(postfix|dovecot|mysql|rspamd|sogo|redis|nginx|php-fpm)-mailcow-1$'

# Tier 1 — mission-critical user-facing
TIER1_NAMES=(
  rmail_landing rswag-landing relos-landing relos-landing-v2 ridentity_landing
  p2p-blog p2p-blogfr p2p-blognl p2p-bloggr
  p2pwiki p2pwiki-db p2pwiki-elasticsearch
  commons-hub-web commons-hub-app commons-hub-directus commons-hub-files
  commons-hub-listmonk commons-hub-postgrest commons-hub-listmonk-db commons-hub-directus-db
  worldplay-website worldplay-listmonk worldplay-listmonk-db
  ghost-crypto-commons ghost-crypto-commons-db
  crypto-commons-listmonk crypto-commons-listmonk-db
  ccg-website ccg-staging
  p2p-forum p2p-db p2p-web
  postiz-p2pf postiz-p2pf-temporal postiz-p2pf-postgres postiz-p2pf-redis
  jefflix
)

# Tier 3 — sandboxes by name pattern; explicit excludes win (e.g. ccg-staging)
TIER3_PATTERN='(-dev$|-staging$|-test$|-stage$|^claude-dev|^test-|sandbox)'
TIER3_EXCLUDE='^(ccg-staging)$'

apply_score() {
  local c="$1" score="$2"
  local pid
  pid=$(docker inspect -f '{{.State.Pid}}' "$c" 2>/dev/null) || return 1
  [ -z "$pid" ] || [ "$pid" = "0" ] && return 1

  echo "$score" > "/proc/$pid/oom_score_adj" 2>/dev/null || return 2
  # Apply to all task threads as well
  for t in /proc/"$pid"/task/*/oom_score_adj; do
    [ -w "$t" ] && echo "$score" > "$t" 2>/dev/null
  done
  return 0
}

t0=0; t1=0; t3=0

# Tier 0 explicit
for c in "${TIER0_NAMES[@]}"; do
  apply_score "$c" -800 && t0=$((t0+1))
done

# Tier 0 pattern (mailcow)
while IFS= read -r c; do
  apply_score "$c" -800 && t0=$((t0+1))
done < <(docker ps --format '{{.Names}}' | grep -E "$TIER0_PATTERN" || true)

# Tier 1 explicit
for c in "${TIER1_NAMES[@]}"; do
  apply_score "$c" -100 && t1=$((t1+1))
done

# Tier 3 by pattern, minus excludes
while IFS= read -r c; do
  [[ "$c" =~ $TIER3_EXCLUDE ]] && continue
  apply_score "$c" 500 && t3=$((t3+1))
done < <(docker ps --format '{{.Names}}' | grep -iE "$TIER3_PATTERN" || true)

stamp=$(date -Iseconds)
msg="applied tier0=$t0 tier1=$t1 tier3=$t3"
logger -t oom-tier-enforcer "$msg"
echo "$stamp $msg"
