#!/usr/bin/env bash
# Retention policy for rotation-backup artifacts (TASK-89 AC #1).
#
# Rotation scripts/runbooks leave timestamped copies behind:
#   *.bak-pre-rotate-*  *.bak-stale-*  *.bak-pre-tls-*
#   *.bak.YYYYMMDD-*    *.bak-YYYYMMDD-*    *.bak.<unixts>
# These are intentional rollback safety nets — but unbounded they're
# stale-credential sprawl. Policy: per logical "stem" (the filename with
# its .bak…timestamp suffix stripped) keep the 2 NEWEST backups
# unconditionally; of the older ones, delete those whose mtime is beyond
# RETAIN_DAYS. So a fresh rollback point always survives, ancient ones go.
#
# DEFAULT IS DRY-RUN. Pass --apply to actually delete.
#
# Scope:
#   local  ~/.secrets/private/
#   netcup /root/.secrets/  /root/traefik/ (+config/)  /opt/syncthing/config/
#          and *.bak-pre-rotate-* under /opt/apps + /opt service dirs
#
# Scheduled monthly via prune-rotation-backups.timer (local user timer;
# this script reaches Netcup over ssh itself).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RETAIN_DAYS="${RETAIN_DAYS:-90}"
KEEP_NEWEST="${KEEP_NEWEST:-2}"
SSH_TARGET="${SSH_TARGET:-netcup-full}"
APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }

# Emit, for a given find-root, the backup files that should be DELETED:
# group by stem, keep newest $KEEP_NEWEST by mtime, then among the rest
# print those older than $RETAIN_DAYS. Pure stdout (paths), one per line.
# Runs locally; for remote we ship this same awk via ssh.
PLAN_AWK='
{
  # $1 = mtime epoch, rest = path
  ep=$1; p=$2;
  stem=p;
  sub(/\.bak[-.][0-9].*$/, "", stem);
  sub(/\.bak-(pre-rotate|stale|pre-tls)-[0-9].*$/, "", stem);
  n[stem]++; rec[stem,n[stem]]=ep "\t" p;
}
END{
  now=systime();
  cutoff=now - RD*86400;
  for (s in n) {
    cnt=n[s];
    # collect (ep,path) for this stem
    delete arr;
    for (i=1;i<=cnt;i++) arr[i]=rec[s,i];
    # sort by ep desc (simple insertion; counts are tiny)
    for (i=1;i<=cnt;i++) for (j=i+1;j<=cnt;j++){
      split(arr[i],a,"\t"); split(arr[j],b,"\t");
      if (b[1]+0 > a[1]+0){ t=arr[i]; arr[i]=arr[j]; arr[j]=t; }
    }
    for (i=1;i<=cnt;i++){
      if (i<=KN) continue;                 # always keep newest KN
      split(arr[i],a,"\t");
      if (a[1]+0 < cutoff) print a[2];      # older than cutoff → delete
    }
  }
}'

collect_local() {
  local root="$1"
  [[ -d "$root" ]] || return 0
  find "$root" -maxdepth 1 -type f \
    \( -name '*.bak-pre-rotate-*' -o -name '*.bak-stale-*' \
       -o -name '*.bak-pre-tls-*' -o -name '*.bak.*' -o -name '*.bak-*' \) \
    -printf '%T@ %p\n' 2>/dev/null \
  | awk '{printf "%d %s\n",$1,$2}' \
  | awk -v RD="$RETAIN_DAYS" -v KN="$KEEP_NEWEST" "$PLAN_AWK"
}

log "prune-rotation-backups (RETAIN_DAYS=$RETAIN_DAYS KEEP_NEWEST=$KEEP_NEWEST APPLY=$APPLY)"

# ---- LOCAL ----
mapfile -t LOCAL_DEL < <(collect_local "$HOME/.secrets/private")
log "LOCAL ~/.secrets/private: ${#LOCAL_DEL[@]} file(s) past policy"
for f in "${LOCAL_DEL[@]}"; do
  if (( APPLY )); then rm -f -- "$f" && echo "  deleted $f"; else echo "  would delete $f"; fi
done

# ---- NETCUP ----
# Ship the same logic over ssh. Roots scanned with -maxdepth so we don't
# walk all of /opt; the .env backups live one level into each app dir.
REMOTE_SCRIPT=$(cat <<REOF
set -uo pipefail
RD=$RETAIN_DAYS; KN=$KEEP_NEWEST; APPLY=$APPLY
plan_awk='$PLAN_AWK'
emit() {
  find "\$1" -maxdepth "\$2" -type f \\
    \\( -name '*.bak-pre-rotate-*' -o -name '*.bak-stale-*' \\
       -o -name '*.bak-pre-tls-*' -o -name '*.bak.*' -o -name '*.bak-*' \\) \\
    -printf '%T@ %p\n' 2>/dev/null \\
  | awk '{printf "%d %s\n",\$1,\$2}' \\
  | awk -v RD="\$RD" -v KN="\$KN" "\$plan_awk"
}
{
  emit /root/.secrets 1
  emit /root/traefik 1
  emit /root/traefik/config 1
  emit /opt/syncthing/config 1
  find /opt -maxdepth 4 -type f -name '*.bak-pre-rotate-*' -printf '%T@ %p\n' 2>/dev/null \\
    | awk '{printf "%d %s\n",\$1,\$2}' | awk -v RD="\$RD" -v KN="\$KN" "\$plan_awk"
} | sort -u | while read -r f; do
  [ -z "\$f" ] && continue
  if [ "\$APPLY" = "1" ]; then rm -f -- "\$f" && echo "  deleted \$f"; else echo "  would delete \$f"; fi
done
REOF
)
log "NETCUP scan:"
ssh "$SSH_TARGET" "bash -s" <<<"$REMOTE_SCRIPT" 2>/dev/null || log "  (netcup pass failed — check ssh)"

(( APPLY )) || log "DRY-RUN — no files removed. Re-run with --apply to enforce."
log "done"
