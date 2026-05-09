# Phased Migration Plan

**Task:** TASK-83 Phase 3
**Date:** 2026-05-08
**Inputs:** [dep-inventory.md](./dep-inventory.md), [replacement-matrix.md](./replacement-matrix.md), [bundle-design.md](./bundle-design.md)
**Goal:** Ordered cutover plan from current CF-dependent stack to vendor-portable bundle. Each phase has prerequisites, rollback, success criteria, est. effort.

---

## Ordering principles

1. **Reversibility first** — phases that can roll back in <5 min go first
2. **Independent functions before coupled ones** — auth swap before DNS, DNS before tunnel
3. **Pilot before bulk** — one site validates the bundle before the other 100+ migrate
4. **Hardware before media** — TASK-66 disks land before R2 → MinIO
5. **No flag day** — cloudflared keeps running until last domain migrates off it

---

## Phase A — Authentik deployment + CF Access swap (week 1-2)

**Goal:** Replace CF Access on `/admin*` paths with Authentik forward-auth.

**Why first:** Identity is fully decoupled from DNS + Tunnel. Affects only protected admin routes (~5-10 routes total). Reversible by reverting Traefik middleware label.

**Prerequisites:**
- Authentik admin email + initial group structure decided
- Inventory of all services using CF Access (**done 2026-05-09** — see [`cf-access-inventory/access-inventory.md`](./cf-access-inventory/access-inventory.md): 32 apps, 39 policies, 3 bypass + 29 allow-listed)
- CrowdSec daemon + bouncer-traefik already deployed at `/opt/apps/crowdsec/` (2026-05-09 immediate-win) — Authentik gets layered alongside, both run concurrently during cutover

**Steps:**
1. Deploy Authentik via bundle's `docker-compose.yml` (subdomain `auth.jeffemmett.com`, CF Tunnel still in front, no DNS change yet)
2. Configure OIDC provider + initial admin user
3. Create `authentik` forward-auth middleware in Traefik dynamic config
4. Migrate one route at a time: Uptime Kuma `/admin*` first (lowest blast radius)
5. Verify: header passthrough works, login flow works, logout works
6. Bulk-migrate remaining `/admin*` routes
7. Disable CF Access policies (don't delete yet — keep as fallback for 1 week)

**Rollback:** Revert Traefik middleware label per route. CF Access policy still in place. <5 min per route.

**Success criteria:**
- All previously CF-Access-protected routes auth via Authentik
- No regression in user experience (passkey or Google OAuth federation working)
- Authentik handles the 5-10 daily auth events without errors for 7 days

**Effort:** 8-16 hours. Authentik first-time setup is the bulk; per-route migration is mechanical.

---

## Phase B — DNS provider swap (week 3-4)

**Goal:** Move authoritative DNS from Cloudflare → deSEC for one pilot domain, then bulk.

**Why before tunnel:** DNS swap is reversible (NS records at registrar). Tunnel swap requires a new ingress endpoint, which needs DNS pointing somewhere.

**Prerequisites:**
- deSEC account created, API token issued
- DNSSEC handover plan (CDS/CDNSKEY records)
- TTL on all current CF DNS records dropped to 300s 48h before cutover (drop early so the ALL-IS-WELL state matters when you flip)

**Steps:**
1. Pick pilot domain — suggest `decolonizeti.me` (low-stakes, single CNAME today)
2. Export all CF DNS records for pilot via `cf-terraforming` or API → JSON
3. Import into deSEC via REST API
4. Verify deSEC serves identical answers via `dig @ns1.desec.io ...`
5. Update NS records at Porkbun (registrar) for pilot domain only
6. Wait 48h, monitor `dig` from multiple geos
7. If clean: bulk-migrate remaining domains in waves of 5

**Rollback:** Revert NS at Porkbun. CF still has all records. <5 min, but 24-48h propagation.

**Success criteria:**
- Pilot domain resolves identically pre/post via 5 global resolvers
- DNSSEC chain unbroken (use [DNSViz](https://dnsviz.net/))
- ACME DNS-01 challenge works against deSEC for cert renewal

**Effort:** 4 hours pilot + ~30 min per subsequent domain. ~30 domains × 30min = 15 hours bulk.

---

## Phase C — Pilot tunnel cutover (week 5-6)

**Goal:** Move ONE low-traffic site from CF Tunnel → Pangolin edge. End-to-end validation of the bundle.

**Pilot pick:** `personal-site` (jeffemmett-website-redesign-personal-site).
- Single container, no DB, no auth, low traffic
- Unique subdomain (e.g., `personal.jeffemmett.com`) — won't impact main `jeffemmett.com`
- Easy to roll back by flipping CNAME

**Prerequisites:**
- OVH VPS provisioned (€5/mo, Frankfurt or London)
- Pangolin server installed on OVH
- Newt agent installed on Netcup, WireGuard tunnel up
- Test domain `pilot.jeffemmett.com` DNS already on deSEC (Phase B done for this domain)

**Steps:**
1. On OVH: install Pangolin per `setup-edge.sh`
2. On Netcup: deploy Newt agent via bundle's `docker-compose.edge.yml` (profile=pangolin)
3. Configure Pangolin to expose `pilot.jeffemmett.com` → Newt → Netcup Traefik
4. Update deSEC: `pilot.jeffemmett.com` A record → OVH public IP (was CF tunnel CNAME)
5. Verify: `curl -v https://pilot.jeffemmett.com/` returns 200, cert is LE-issued
6. Run for 7 days, monitor latency + uptime via Uptime Kuma push monitor
7. Compare metrics: latency vs CF baseline (expect +50-200ms for distant users)

**Rollback:** Revert DNS A → CF tunnel CNAME. <5 min + DNS TTL.

**Success criteria:**
- Pilot site uptime ≥ 99.9% over 7 days
- Latency p50 ≤ 300ms from EU/US (anycast loss measurable but tolerable)
- TLS cert auto-renews on Pangolin edge
- Authentik forward-auth still works on protected routes

**Effort:** 12-20 hours including OVH setup + Pangolin learning curve.

---

## Phase D — Bulk tunnel migration (week 7-12)

**Goal:** Move all remaining domains/services from CF Tunnel → Pangolin in waves.

**Why slow:** 447 containers, ~30 public domains, ~150+ subdomains. Wave migration reduces blast radius and lets ops fatigue recover between batches.

**Wave structure (5 domains per wave, 1 wave per week):**

| Wave | Domains | Notes |
|---|---|---|
| 1 | personal sites only (5) | already pilot-tested shape |
| 2 | static product sites (5) | bondingcurve, conviction-voting, mycostack, etc. |
| 3 | low-traffic apps (5) | rdata, rstack, rtrips, rfunds, rcart |
| 4 | medium apps (5) | listmonk, n8n, postiz, twenty-cl, twenty-cc |
| 5 | high-traffic / commerce (5) | payment-forge, hyperswitch, commons-hub |
| 6 | remaining (5) | jellyfin, immich, p2pwiki |

**Per-wave protocol:**
1. Pre-flight: confirm DNS for each domain already migrated to deSEC (Phase B)
2. Add Pangolin entry per domain (via Pangolin web UI, no Newt config change needed)
3. Update DNS A record at deSEC: `<domain>` → OVH public IP
4. Verify: HTTP check + auth flow + any domain-specific feature
5. Remove `cloudflared` ingress entry for the domain (don't restart cloudflared yet — batch the restart)
6. End of wave: `docker restart cloudflared` to drop migrated domains

**Rollback:** Revert DNS A back to CF CNAME, restore cloudflared ingress entry. <10 min per domain.

**Success criteria per wave:**
- All wave's domains pass HTTP smoke test
- Authentik auth works on protected paths
- 7-day uptime ≥ 99.9% for the wave before starting next

**Effort:** ~6 weeks elapsed, ~4 hours per wave = 24 hours total work.

---

## Phase E — Cloudflared decommission (week 13)

**Goal:** Verify nothing left on cloudflared, remove the systemd unit.

**Prerequisites:** All public-facing domains migrated to Pangolin (Phase D done).

**Steps:**
1. Inspect `cloudflared` config — list any remaining ingress entries
2. For each: confirm with `dig` that DNS no longer points at the tunnel
3. `systemctl stop cloudflared && systemctl disable cloudflared`
4. Wait 7 days. Watch for any breakage.
5. Remove cloudflared binary + config files
6. Delete tunnel from CF dashboard
7. Move CF account to "DNS-only" (no proxied records) before final off-boarding

**Rollback:** `systemctl start cloudflared` and re-add ingress. Original config preserved in `/root/.cloudflared/config.yml.bak`. <2 min.

**Effort:** 4 hours.

---

## Phase F — Object storage migration (R2 → MinIO) — gated on TASK-66

**Goal:** Move Plex/Jellyfin media from CF R2 → MinIO on local hardware.

**Why gated:** TASK-66 (MS-S1 Max + 2x 20TB Ultrastar disks) provides the destination. Migrating to a temp B2 bucket first is wasted I/O.

**Prerequisites:**
- TASK-66 hardware delivered + provisioned
- MinIO deployed on new hardware via bundle's `docker-compose.storage.yml`
- WireGuard tunnel from Netcup ↔ new hardware (probably via Headscale)

**Steps:**
1. Measure: `rclone size r2:plex-media` — how much data exactly?
2. Provision MinIO bucket `plex-media` on new hardware
3. Background sync: `rclone sync r2:plex-media minio:plex-media --transfers=4 --bwlimit=20M` (rate-limit to stay under egress threshold)
4. Continue Jellyfin reads from R2 during sync
5. Final delta sync: `rclone sync ... --update`
6. Update `r2-mount` compose to point at MinIO endpoint
7. `docker compose up -d r2-mount` (now MinIO-mount)
8. Verify: Jellyfin still plays media
9. Delete CF R2 bucket after 30-day verification window

**Rollback:** Revert rclone config to R2. Data still there during 30-day window. <5 min.

**Effort:** 8-40 hours depending on data size. Mostly wall-clock, not active work.

**Cost gotcha:** R2 egress to non-CF endpoints is $0.015/GB. 5TB → $75 one-time. Schedule at month boundary to align with R2 free egress allowance reset.

---

## Phase G — MCP SaaS swaps (week 14+, parallel)

**Goal:** Replace remaining SaaS MCP servers with local equivalents.

These are independent and can run in parallel.

| MCP | Replacement | Effort |
|---|---|---|
| Gemini → Llama 3.2 Vision | Ollama already has the model alias slot. Wait for TASK-66 hardware (Strix Halo runs vision well). | 2h |
| fal-ai → ComfyUI | Deploy ComfyUI in API mode on TASK-66. Wrap in MCP shim. | 8h |
| runpod-image-gen → ComfyUI | Same as fal-ai swap. | 0 (covered above) |
| Calendar → SOGo | SOGo already in Mailcow. Write CalDAV MCP shim. | 4h |
| Xero | KEEP — accepted vendor exception | 0 |
| Figma | KEEP for legacy + Penpot for new work | 0 |

**Effort:** 14 hours total, parallelizable.

---

## Phase H — Bundle packaging + portability test (week 16)

**Goal:** Produce the actual deliverable — a bundle that deploys to a fresh VPS.

**Prerequisites:** All migration phases complete; current Netcup state == bundle target state.

**Steps:**
1. Extract running config from Netcup into bundle structure
2. Anonymize secrets (replace with `${VAR}` placeholders, document in `.env.example`)
3. Write `bootstrap.sh` per [bundle-design.md](./bundle-design.md)
4. Test on fresh Hetzner CX22 (€4/mo): `git clone bundle && ./bootstrap.sh`
5. Verify: serves a public HTTPS site for `bundle-test.jeffemmett.com` end-to-end
6. Tear down test VPS
7. Tag bundle release v1.0

**Success criteria:**
- Bundle clones + bootstraps on fresh Debian 12 VPS in <30 min
- Single HTTPS site reachable end-to-end from public Internet
- Authentik admin login works
- restic backup created and restorable

**Effort:** 16-24 hours including doc polish.

---

## Total timeline

| Phase | Weeks | Effort (hrs) |
|---|---|---|
| A — Authentik + CF Access | 1-2 | 8-16 |
| B — DNS swap | 3-4 | ~19 (pilot + bulk) |
| C — Pilot tunnel | 5-6 | 12-20 |
| D — Bulk tunnel | 7-12 | 24 |
| E — Cloudflared decom | 13 | 4 |
| F — R2 → MinIO | TASK-66+ | 8-40 |
| G — MCP swaps | 14+ | 14 |
| H — Bundle packaging | 16 | 16-24 |
| **Total** | **~16 weeks** | **~110-160 hrs** |

---

## Hard dependencies between phases

```
A (Authentik) ─────────┐
                       │
B (DNS) ───────► C (pilot tunnel) ───► D (bulk tunnel) ───► E (decom) ───► H (bundle)
                                                                              ▲
TASK-66 (hardware) ───► F (R2 → MinIO) ──────────────────────────────────────┘
                       │
                       └─► G (MCP swaps)
```

Phase A and Phase B can run in parallel. Phase C blocks on B. Phase D blocks on C. Phase F+G block on TASK-66 hardware.

---

## Anti-goals

- **No flag day** — cloudflared keeps running until last domain migrates
- **No big-bang DNS swap** — domains move in waves, with TTL drops 48h before each wave
- **No data migration before hardware** — R2 → temp B2 → MinIO is wasted bandwidth
- **No CF account deletion** — keep account in DNS-only mode for 90 days post-decom in case rollback needed

---

## Open questions for Phase 4 (TCO + risk)

- Is DDoS protection worth €60/yr OVH-edge cost vs accepting single-VPS exposure?
- What's the actual current spend on CF R2 + RunPod? Determines whether savings justify the migration effort.
- Is the 16-week timeline acceptable, or should we accept partial migration (Phases A+B only)?
