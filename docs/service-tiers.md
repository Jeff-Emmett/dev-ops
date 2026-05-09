# Service Tiering — OOM Priority Model

**Established:** 2026-05-09 (TASK-HIGH.9)
**Current phase:** Phase A (transient `/proc` writes via systemd timer)

---

## Why This Exists

2026-05-09: three simultaneous crashloops — `engine-pool-redis`, `ofelia-mailcow`, `jefflix`. Root cause: stale cgroup `mem_limit` values surviving Docker daemon restarts, no priority differentiation between production and sandbox containers. Under memory pressure the kernel kills containers at random. Sandboxes and experimental deploys were competing equally with mission-critical services for the same 62 GB RAM pool.

Result: Traefik could route fine while listmonk and its DB died in OOM loops. Unacceptable.

The tiering system gives the kernel explicit kill-order guidance via `oom_score_adj`. Infrastructure containers become nearly unkillable; sandboxes volunteer to die first.

---

## The 4-Tier Model

| Tier | Label | `oom_score_adj` | `mem_reservation` | `restart` policy | Behaviour under pressure |
|------|-------|-----------------|-------------------|------------------|--------------------------|
| **0** | Infrastructure | `-800` | 512 MB – 1 GB | `always` | Must never die. Kernel will exhaust everything else first. |
| **1** | Mission-critical user-facing | `-100` | 256 – 512 MB | `unless-stopped` | High availability. Survives most pressure events. |
| **2** | Production tolerable | `0` (default) | none / low | `unless-stopped` | Recovers in minutes. Not explicitly protected. |
| **3** | Sandbox / dev / staging | `+500` | none | `on-failure:3` | Kill first. Explicitly volunteered as OOM candidates. |

### Tier 0 — Infrastructure

Containers in this tier are specified by exact name or regex pattern in `enforce-oom-tiers.sh`.

**Explicit names:**
`traefik`, `infisical`, `gitea`, `uptime-kuma`, `restic`, `crowdsec`

**Pattern (mailcow core):**
```
^mailcowdockerized-(postfix|dovecot|mysql|rspamd|sogo|redis|nginx|php-fpm)-mailcow-1$
```

### Tier 1 — Mission-Critical User-Facing

All r-suite landings, P2P stack, commons-hub stack, worldplay, crypto-commons, CCG, postiz (p2pf). Full list in the `TIER1_NAMES` array. See `netcup/scripts/enforce-oom-tiers.sh` for canonical source.

Live `oom_score_adj` values confirmed 2026-05-09: `p2p-blog=-100`, `ccg-website=-100`, `jefflix=-100`.

### Tier 2 — Production Tolerable

Everything not explicitly listed. `oom_score_adj` stays at kernel default `0`. Includes most single-tenant tools, internal services, DBs not serving Tier 1 directly.

### Tier 3 — Sandbox / Dev / Staging

Matched by pattern in `enforce-oom-tiers.sh`:
```
(-dev$|-staging$|-test$|-stage$|^claude-dev|^test-|sandbox)
```

Explicit excludes (pattern match wins, but these are promoted out of Tier 3):
```
^(ccg-staging)$
```

Confirmed Tier 3 containers 2026-05-09: `claude-dev=+500`, `rspace-online-dev=+500`, `rspace-zk-staging=+500`.

---

## How the Timer Self-Heals

`/proc/<pid>/oom_score_adj` is a per-process kernel attribute. It does **not** persist across container restarts — when Docker recreates a container, the new PID gets the default value `0`.

The timer fires every 5 minutes and re-applies all tier assignments by re-reading live Docker PIDs. Any container that restarted or was newly deployed in the last 5-minute window gets corrected automatically.

```
# systemd timer behaviour
OnBootSec=60s          — first run 60s after boot
OnUnitActiveSec=5min   — then every 5 minutes
Persistent=true        — catches missed fires (e.g. system was asleep)
```

Logs at `/var/log/enforce-oom-tiers.log`. Each run prints:
```
2026-05-09T22:10:03+00:00 applied tier0=13 tier1=35 tier3=12
```

---

## Phase A vs Phase B

### Phase A (current)

- Transient `/proc` writes via systemd timer
- Covers all running containers within 5 minutes of any change
- No Docker Compose source edits required

**Status:** Live. Timer enabled, `enforce-oom-tiers.sh` deployed to `/opt/scripts/` on Netcup.

### Phase B (deferred)

- Edit all Tier 0/1 Compose files to add `oom_score_adj`, `mem_reservation`, and correct `restart` policy
- Force-recreate containers to apply cgroup changes (restart is not enough for cgroup edits)
- Source-of-truth lives in Compose files, not only in the enforcement script

**Status:** Deferred. Phase A already prevents the failure mode that triggered this work. Phase B is a hygiene/correctness improvement — do it in a dedicated session when touching those services anyway.

---

## Adding a Service to a Tier

### Step 1 — Edit the script

File: `netcup/scripts/enforce-oom-tiers.sh`

- **Tier 0 explicit**: add container name to `TIER0_NAMES` array
- **Tier 0 pattern**: extend `TIER0_PATTERN` regex if it's a multi-container stack like mailcow
- **Tier 1**: add container name(s) to `TIER1_NAMES` array
- **Tier 3**: pattern-matched automatically; add to `TIER3_EXCLUDE` to pull a service *out* of Tier 3

New services default to Tier 2 (no action needed) unless they match a Tier 3 pattern.

### Step 2 — Deploy

```bash
scp netcup/scripts/enforce-oom-tiers.sh netcup:/opt/scripts/
ssh netcup 'chmod +x /opt/scripts/enforce-oom-tiers.sh && systemctl restart enforce-oom-tiers.service'
```

### Step 3 — Verify

```bash
# Check the container's current PID
docker inspect -f '{{.State.Pid}}' <container-name>

# Verify oom_score_adj was applied
cat /proc/<pid>/oom_score_adj

# Check last timer run
systemctl list-timers enforce-oom-tiers.timer

# Tail the log
tail -20 /var/log/enforce-oom-tiers.log
```

Expected values: Tier 0 → `-800`, Tier 1 → `-100`, Tier 2 → `0`, Tier 3 → `500`.

---

## Limitations

1. **Transient** — `/proc` writes reset on container restart. Timer compensates within 5 min. Phase B (compose edits) eliminates the gap entirely.

2. **OOM score is advisory** — `oom_score_adj=-800` makes Tier 0 containers extremely unlikely to be killed, but the kernel will still kill them if the host runs out of memory entirely and there are no other candidates. Nothing short of `mem_limit` on every other container fully prevents this.

3. **No `mem_limit` enforcement** — the timer sets priority order only; it does not cap how much RAM any container can allocate. A runaway Tier 1 container can still exhaust the host. Set `mem_limit` in Compose for known-large services (Phase B).

4. **Pattern matching is naive** — Tier 3 pattern matches on container name substrings. A service named `test-runner-prod` would be mis-tiered as Tier 3. Audit with `docker ps --format '{{.Names}}' | grep -iE '(-dev$|-staging$|-test$|-stage$|^claude-dev|^test-|sandbox)'` periodically.

5. **New stacks need explicit Tier 1 registration** — Tier 1 is opt-in. New production deployments land at Tier 2 (OOM score 0) until added to `TIER1_NAMES`. Add at deploy time.

---

## Verification Commands

```bash
# Show oom_score_adj for a specific container
CNAME=traefik
PID=$(docker inspect -f '{{.State.Pid}}' $CNAME)
cat /proc/$PID/oom_score_adj          # expect -800

# Show all running containers with their current oom_score_adj
docker ps --format '{{.Names}}' | while read c; do
  pid=$(docker inspect -f '{{.State.Pid}}' "$c" 2>/dev/null)
  [ -n "$pid" ] && [ "$pid" != "0" ] && printf "%-40s %s\n" "$c" "$(cat /proc/$pid/oom_score_adj 2>/dev/null)"
done | sort -k2 -n

# Check timer status
systemctl status enforce-oom-tiers.timer
systemctl list-timers enforce-oom-tiers.timer

# Tail enforcer log
tail -50 /var/log/enforce-oom-tiers.log

# Force an immediate re-apply
systemctl start enforce-oom-tiers.service
```

---

## Recovery Playbook — Tier 0 Service Death

Tier 0 services should not die under normal operation. If one does, treat it as a P0 incident.

### 1. Triage (< 2 min)

```bash
# Confirm it's dead and get last known state
docker ps -a | grep <service-name>
docker logs --tail 100 <service-name>

# Check for OOM kill in kernel ring buffer
dmesg | grep -iE 'oom|kill' | tail -20

# Check system memory state at time of death
dmesg | grep -A5 'Out of memory'
```

### 2. Immediate restart

```bash
docker start <service-name>
# or for always-restart services that aren't recovering:
docker rm -f <service-name>
cd /opt/apps/<stack-dir>
docker compose up -d <service-name>
```

### 3. Re-apply tier scores

```bash
systemctl start enforce-oom-tiers.service
cat /proc/$(docker inspect -f '{{.State.Pid}}' <service-name>)/oom_score_adj
```

### 4. Root-cause

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `oom_score_adj=0` at time of kill | Timer missed a window after restart | Check `enforce-oom-tiers.timer` status; restart if inactive |
| `Killed process … anon-rss` in dmesg | Another container consumed all RAM | Identify the RSS hog: `docker stats --no-stream \| sort -k4 -rh`; add `mem_limit` to offender |
| Container exits 137 without OOM in dmesg | Docker killed it via `--memory` cgroup limit | Raise `mem_limit` in Compose; force-recreate |
| Container exits 1 / segfault | Application crash, not OOM | Check application logs; restart and monitor |

### 5. Post-incident

- Note the container name and RSS at time of OOM in the incident log
- If the kill was preventable with `mem_limit` on another container, create a follow-up task
- If `oom_score_adj` was `0` at time of kill (Phase A gap), escalate to Phase B for that service

---

## Related Files

| File | Purpose |
|------|---------|
| `netcup/scripts/enforce-oom-tiers.sh` | Canonical tier membership + enforcement logic |
| `netcup/scripts/enforce-oom-tiers.service` | systemd oneshot service |
| `netcup/scripts/enforce-oom-tiers.timer` | 5-min periodic trigger |
| `backlog/tasks/task-high.9 - Establish-service-tiering-…md` | Original task, Phase B follow-ups |
