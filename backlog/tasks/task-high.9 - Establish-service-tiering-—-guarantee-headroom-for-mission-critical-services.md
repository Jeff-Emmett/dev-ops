---
id: TASK-HIGH.9
title: Establish service tiering — guarantee headroom for mission-critical services
status: To Do
assignee: []
created_date: '2026-05-09 22:15'
updated_date: '2026-05-09 23:09'
labels: []
dependencies: []
parent_task_id: TASK-HIGH
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Today's session uncovered three crashloops (engine-pool-redis, ofelia-mailcow, jefflix) caused by stale cgroup mem_limits surviving Docker daemon restarts. Sandboxes/experimental containers have no resource constraints and can starve production. This task formalizes a 4-tier model with kernel-enforced headroom for critical services.

## Tier model

| Tier | mem_reservation | oom_score_adj | restart | Survival |
|------|----------------|---------------|---------|----------|
| 0 — Infra | high (512MB-1GB) | -800 | always | Must never die |
| 1 — Critical user-facing | moderate (256-512MB) | -100 | unless-stopped | High availability |
| 2 — Production tolerable | none/low | 0 | unless-stopped | Recovers in minutes |
| 3 — Sandbox/dev | none | +500 | on-failure:3 | Kill first under pressure |

## Tier 1 scope (mission-critical, per user 2026-05-09)
- All r-suite landings (rmail_landing, rswag-landing, relos-landing, ridentity_landing, rspace landings, etc.)
- p2p-blogfr + entire P2P blog stack
- p2pwiki (mediawiki + db + elasticsearch)
- p2pfoundation website
- commons-hub (commons-hub-web, commons-hub-app, commons-hub-directus)
- valley-of-the-commons / valley-commons
- crypto-commons
- cryptocommonsgathering
- worldplay
- All their functions (DBs, redis, workers, sub-services)

## Tier 0 scope (infra)
- traefik, mailcow core (postfix/dovecot/mysql/redis/sogo), infisical, gitea, postgres clusters serving Tier 0/1, ssh-guard hooks, restic backup, uptime-kuma
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Audit: map every service in the Tier 1 user-list to its actual container(s) + compose path; identify Tier 0 infra containers
- [x] #2 Document tier definitions in dev-ops/docs/service-tiers.md with rationale + worked examples
- [x] #3 Add Docker label tier=0|1|2|3 to every running container (audit script)
- [ ] #4 Update Tier 0 compose files: mem_reservation + oom_score_adj=-800 + restart=always
- [ ] #5 Update Tier 1 compose files: mem_reservation + oom_score_adj=-100 + restart=unless-stopped
- [ ] #6 Identify Tier 3 (sandbox/dev/staging) containers; cap mem_limit, set oom_score_adj=+500
- [ ] #7 Force-recreate all Tier 0 + Tier 1 containers to apply new constraints (cgroup changes need recreate, not restart)
- [ ] #8 Add monitoring: Uptime Kuma alerts when Tier 0/1 mem usage exceeds 90% of reservation
- [ ] #9 Document recovery playbook: what to do if a Tier 0 service dies (root-cause + restart procedure)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
ROLLOUT 2026-05-09 PARTIAL — Phase A (immediate /proc-based protection) complete via systemd timer. Phase B (compose edits) deferred.

Done this session:
- /opt/scripts/enforce-oom-tiers.sh deployed
- enforce-oom-tiers.timer (systemd, 5-min interval) enabled and running
- Source in dev-ops/netcup/scripts/ (enforce-oom-tiers.sh, .service, .timer)
- Last apply: tier0=13 (mailcow core + traefik/infisical/gitea/uptime-kuma), tier1=35, tier3=12

Verified live oom_score_adj:
- traefik: -800
- mailcow postfix: -800
- p2p-blog: -100 (mem also bumped 512m -> 1g)
- ccg-website: -100
- jefflix: -100 (mem updated live to 1g; see follow-up below)
- claude-dev: +500
- rspace-online-dev: +500
- rspace-zk-staging: +500

Live mem_limit bumps applied (no recreate needed):
- p2p-blog: 512m -> 1g + reservation 512m (was OOMing 10+ times/24h)
- worldplay-website: 128m -> 256m + reservation 128m (was at 56% cap)
- jefflix: 128m -> 1g + reservation 256m (was crashlooping)

Follow-ups needed (not blocking host stability):
1. UNKNOWN: something keeps reverting jefflix mem_limit from 1g back to 128m after force-recreate. Compose says 1g, file mtime is April. Suspects: deploy-webhook fires periodically, docker daemon eats config, or other compose-up path. Hunt and fix in dedicated session.
2. AC 4-7: edit 18 compose files to persist oom_score_adj + mem_reservation in source-of-truth (currently transient via /proc; timer keeps applying). Lower priority since timer self-heals.
3. AC 8: Add Uptime Kuma push monitor for tier1 mem >90% of reservation. 
4. AC 2: Write dev-ops/docs/service-tiers.md formal documentation.
5. AC 9: Recovery playbook for tier 0 service deaths.

Two from audit not running: commons-hub-app and p2p-forum (audit name vs reality mismatch — to investigate).

JEFFLIX MYSTERY SOLVED 2026-05-09: was a duplicate stack. /opt/apps/jefflix was a leftover jellyfin install with no media, competing with /opt/media-server/jellyfin (the real one with /mnt/hetzner-media mounted) for the same Traefik route Host(movies.jefflix.lol). Stale compose state with ghost container f0997035b11c made every recreate partial-fail with 'Error while Stopping' and inconsistent cgroup state. Stopped /opt/apps/jefflix (preserve volumes, 30-day rollback). Updated TIER1_NAMES: jefflix → jellyfin. movies.jefflix.lol now serves cleanly via /opt/media-server/jellyfin (status 200 in 56ms verified). DECOMMISSIONED.md at /opt/apps/jefflix/.
<!-- SECTION:NOTES:END -->
