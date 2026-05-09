# TCO + Risk Register

**Task:** TASK-83 Phase 4
**Date:** 2026-05-08
**Inputs:** [dep-inventory.md](./dep-inventory.md), [replacement-matrix.md](./replacement-matrix.md), [bundle-design.md](./bundle-design.md), [migration-plan.md](./migration-plan.md)
**Goal:** Estimate current vendor spend, project TCO across 3 candidate stacks, register risks with mitigations. Equip the user to pick a stack.

---

## Current annual vendor spend — baseline

All figures rough; treat ranges as "order of magnitude."

| Vendor | Service | Est. annual | Confidence | Notes |
|---|---|---|---|---|
| **Cloudflare** | DNS + Tunnel + Access | **$0** | high | All on free tier |
| **Cloudflare** | R2 storage (`r2-mount` for Plex media) | **$0-$900** | **LOW — verify** | 10GB free; storage cost = $0.015/GB/mo. Phase 4-action: `rclone size r2:plex-media` to confirm |
| **Cloudflare** | R2 egress to CF edge | $0 | high | Free egress to CF (this is the lock-in) |
| **Porkbun** | Domain registrar | **~$300** | medium | ~30 domains × ~$10/yr avg, varies by TLD |
| **Netcup** | RS 8000 G12 Pro | **~$250** | high | €16-24/mo |
| **RunPod** | GPU vLLM burst (Qwen3-Coder) | **$400-$1,200** | medium | Usage-based; depends on coding session volume |
| **Google AI** | Gemini API (MCP) | **$60-$240** | medium | Light use |
| **Fal AI** | Image gen API (MCP) | **$60-$180** | medium | Light use |
| **Xero** | Accounting subscription | **$300-$840** | medium | Plan-dependent |
| **Figma** | Design subscription | **$0-$144** | medium | Free starter or $12/mo Pro |
| **Tailscale** | Coordination server | **$0** | high | Already replaced by self-hosted Headscale |
| **GitHub** | Mirror | **$0** | high | Mirror-only, no paid features |
| **Let's Encrypt** | TLS CA | **$0** | high | Free, ACME standard |
| **TOTAL (rough)** | | **~$1,370 – $4,054 / year** | | |

**Action item before Phase 1 of migration:** verify the two LOW-confidence numbers (R2 storage volume, RunPod usage). They dominate the projection.

---

## Three candidate stacks — projected TCO

### Stack 1 — Bunny.net consolidation

**What it does:** Swap CF as edge but keep a single managed vendor. DNS + CDN + Storage + Pages + Shield WAF all in Bunny.

**Cost delta:**

| Item | Annual |
|---|---|
| Bunny DNS | $0 (bundled with CDN) |
| Bunny CDN bandwidth (~500 GB/mo at $0.01/GB tier) | ~$60 |
| Bunny Storage (50 GB web assets at $0.01/GB/mo) | ~$6 |
| Bunny Shield WAF | $120 |
| **Net change vs baseline** | **~+$186/yr** |

**Keeps:** Netcup origin, Porkbun registrar, Mailcow, Gitea, Headscale, Ollama, RunPod (until TASK-66).

**Removes:** CF entirely.

**Pros:**
- Real anycast (119 PoPs) preserved
- Real DDoS scrubbing preserved
- One vendor swap, not 12

**Cons:**
- Still vendor lock-in, just a different vendor
- Doesn't satisfy the "no external dependencies" goal
- WAF $10/mo is the only meaningful added cost

**Verdict:** Pragmatic but **fails the stated goal** — "fully self-hosted and open source so we can package everything up without external dependencies." Document as fallback, not target.

---

### Stack 2 — Pangolin + OVH edge + Netcup origin (the bundle target)

**What it does:** Self-host edge tunnel + WAF on €5/mo OVH (free DDoS), origin stays on Netcup, all infra software OSS. This is the [bundle-design.md](./bundle-design.md) primary configuration.

**Cost delta:**

| Item | Annual |
|---|---|
| OVH VPS (Pangolin edge, free DDoS) | ~$65 |
| MinIO storage on existing/new disks | $0 (capex covered by TASK-66) |
| Authentik / Coraza / CrowdSec / restic / ComfyUI | $0 (OSS) |
| Backblaze B2 backup target (alt) | ~$60 (1 TB encrypted, optional) |
| **Net change vs baseline (with TASK-66 in place)** | **~$65-$125/yr added** |

**Keeps:** Netcup origin, Porkbun registrar, Let's Encrypt, Mailcow, Gitea, Headscale.

**Removes:** CF entirely, RunPod (after TASK-66), Gemini/fal-ai MCP (after TASK-66), GitHub mirror (optional).

**Savings (after TASK-66 hardware paid down):**
| Removed | Annual saved |
|---|---|
| RunPod GPU (replaced by MS-S1 Max) | $400-$1,200 |
| Gemini + fal-ai MCP | $120-$420 |
| CF R2 (if currently > free tier) | $0-$900 |
| **Total saved** | **$520-$2,520 / yr** |

**Net annual after TASK-66 amortizes:** **−$455 to −$2,395 / yr** (i.e., savings, not added cost).

**Hardware payback:** TASK-66 ~$4,017 one-time; payback at midpoint savings ~$1,500/yr = **~2.7 years**.

**Pros:**
- Meets the stated goal — fully self-hosted, OSS-only
- Vendor-portable: every knob in `.env`
- Bundle clones to a fresh VPS and runs
- TASK-66 hardware unlocks real savings + privacy

**Cons:**
- Lose CF Tbps DDoS scrubbing (replaced by OVH L3/L4 free + Coraza L7 — adequate, not equivalent)
- Single edge PoP (latency hit for distant users; tolerable for our user base)
- 110-160 hours of migration work over ~16 weeks

**Verdict:** **The target stack.** Aligns with stated goal, has positive ROI after hardware, vendor-portable.

---

### Stack 3 — Hybrid (CF DNS+Tunnel kept, only CF Access → Authentik)

**What it does:** Minimum-viable de-risking. Keep CF for the hard parts (DNS anycast, Tunnel ingress, edge DDoS), only swap CF Access since that's the most identity-coupled vendor lock-in.

**Cost delta:**

| Item | Annual |
|---|---|
| Authentik on Netcup | $0 |
| **Net change vs baseline** | **$0** |

**Keeps:** Everything currently in place plus Authentik.

**Removes:** Only CF Access.

**Pros:**
- ~Free, ~16 hours of work
- Removes the single most uncomfortable CF dependency (auth)
- Reversible per-route

**Cons:**
- **Does not meet the stated goal** — CF DNS/Tunnel/R2 still in path
- Most third-party MCP and SaaS still in place
- Bundle is not portable

**Verdict:** Useful as a **Phase A milestone**, not a destination. Confirms Authentik works before committing to the larger migration.

---

## Stack comparison summary

| | Stack 1 (Bunny) | **Stack 2 (Pangolin) ★** | Stack 3 (Hybrid) |
|---|---|---|---|
| Meets "no external deps" goal | ✗ | **✓** | ✗ |
| Annual cost change | +$186 | −$455 to −$2,395 (post-TASK-66) | $0 |
| Migration effort | ~40 hrs | ~110-160 hrs | ~16 hrs |
| DDoS protection | ✓ (real anycast scrubbing) | ✓ (OVH free L3/L4 + Coraza L7) | ✓ (CF retained) |
| Anycast latency | ✓ (119 PoPs) | ✗ (single edge PoP) | ✓ (CF retained) |
| Vendor count | 1 (Bunny) | 0 (excluding accepted Xero exception) | 1 (CF) |
| Bundle portable to fresh VPS | ✗ | **✓** | ✗ |

★ = recommended target.

---

## Risk register

### R1 — DDoS protection downgrade
- **Risk:** Single-VPS deploy of bundle has no Tbps scrubbing. A 100Gbps+ flood would saturate Netcup's NIC.
- **Likelihood:** Low for a homelab (no obvious target profile). Higher if any service goes viral.
- **Impact:** Total outage during attack.
- **Mitigation:** Run Pangolin on OVH edge VPS (€60/yr). OVH bundles real DDoS protection. Origin (Netcup) only reachable via WireGuard from edge.
- **Residual:** OVH protection is L3/L4 + some L7; not Tbps anycast scrubbing. Acceptable for current threat profile.
- **Status:** ACCEPTED with mitigation

### R2 — Anycast latency loss
- **Risk:** Single edge PoP means users in AU/Asia/SA see +50-200ms TTFB.
- **Likelihood:** Certain (physics).
- **Impact:** UX degradation for ~10-15% of users (estimated based on traffic geo).
- **Mitigation A:** Add Bunny CDN as static-asset edge ($5-15/mo) — best of both, OSS origin + anycast static.
- **Mitigation B:** Add a second edge VPS in a different region (US-East), use GeoDNS at deSEC.
- **Mitigation C:** Accept the latency.
- **Status:** OPEN — choose mitigation in implementation

### R3 — R2 egress one-time cost
- **Risk:** Migrating Plex/Jellyfin media off CF R2 incurs $0.015/GB egress.
- **Likelihood:** Certain.
- **Impact:** ~$75 one-time for 5TB.
- **Mitigation:** Schedule transfer at month boundary (R2 free egress allowance resets monthly). Rate-limit rclone to avoid spike charges.
- **Status:** ACCEPTED, low cost

### R4 — Authentik ops burden
- **Risk:** Self-hosting an IdP adds a moving part. Outage of Authentik blocks `/admin` paths.
- **Likelihood:** Medium (depends on update discipline).
- **Impact:** Admin lockout — public services unaffected.
- **Mitigation:** Maintain a break-glass local admin via Traefik basic-auth as fallback middleware. Enable Authentik recovery codes. Snapshot `authentik-postgres-data` daily via restic.
- **Status:** ACCEPTED with mitigation

### R5 — DNS migration mistakes
- **Risk:** NS record swap with DNSSEC mid-flight can break resolution for 24-48h.
- **Likelihood:** Medium without discipline.
- **Impact:** Domain unreachable until propagation completes.
- **Mitigation:** TTL drop to 300s 48h before NS swap. Migrate one domain first as pilot. Verify deSEC serves identical answers via `dig` before NS swap. CDS/CDNSKEY handover documented.
- **Status:** ACCEPTED with mitigation

### R6 — Backup destination unknown
- **Risk:** `db-backup-cron` is running but Phase 0 couldn't confirm where it sends backups. Could be CF R2 (silent dependency) or local-only (silent risk).
- **Likelihood:** Certain (the script exists; question is what it does).
- **Impact:** If R2: silent CF dependency. If local-only: no off-site backup.
- **Mitigation:** Phase 2 implementation must `cat` the cron script + inventory targets BEFORE designing restic to replace it.
- **Status:** **CLOSED 2026-05-09.** Investigated during immediate-wins pass. Active backup pipeline is `/opt/backup-system/backup-docker.sh` (NOT the `/opt/apps/db-backup` zombie). It is already 3-2-1 compliant: daily restic snapshots to `r2:netcup-backups` + Hetzner Storage Box sync as second offsite. Auto-discovers all postgres/mariadb containers. Phase F (R2 → MinIO) absorbs the CF dependency removal. The zombie predecessor was decommissioned + archived to `/opt/apps/db-backup.zombie-2026-05-09/`.

### R7 — Pangolin B-grade maturity at scale
- **Risk:** Pangolin is younger than CF Tunnel. Has it handled 100+ services in production?
- **Likelihood:** Unknown without reference deployments.
- **Impact:** Bundle's primary edge component fails under load.
- **Mitigation:** Phase C (pilot tunnel) is the smoke test. If Pangolin chokes, fall back to frp + Traefik + Authentik separately (B+ vs A maturity, more pieces but battle-tested).
- **Status:** OPEN — pilot validates

### R8 — Xero accepted vendor exception
- **Risk:** Stack still depends on Xero (no realistic OSS replacement).
- **Likelihood:** Permanent until Akaunting or similar matures.
- **Impact:** Bundle can't claim "zero vendor deps" honestly.
- **Mitigation:** Document as accepted exception. Use Xero MCP read-only to keep workflow lock-in shallow.
- **Status:** ACCEPTED, documented

### R9 — Migration timeline (16 weeks) vs availability
- **Risk:** Active product work + day-job will compete with 110-160hrs of migration time.
- **Likelihood:** Certain.
- **Impact:** Migration drags to 6+ months, partial state risks accumulating.
- **Mitigation:** Each phase has rollback. Stop after Phase A or B if energy runs out — partial migration is still useful.
- **Status:** ACCEPTED, monitor

### R10 — Bundle portability untested until Phase H
- **Risk:** Bundle might work on Netcup but fail on a fresh VPS due to undocumented assumptions (kernel, IPv6, UFW rules).
- **Likelihood:** Medium.
- **Impact:** Bundle "works on my machine" — fails the goal.
- **Mitigation:** Phase H mandates clean-VPS deploy test on a Hetzner CX22 (€4/mo) before tag v1.0.
- **Status:** ACCEPTED, gated

---

## Open questions for the user before implementation begins

1. **Verify R2 spend** — run `rclone size r2:plex-media` + check CF dashboard for current month usage. Determines whether savings are $0/yr or $900/yr.
2. **Verify RunPod spend** — check RunPod dashboard for last 90 days. Determines payback period for TASK-66.
3. **Choose latency mitigation (R2)** — Mitigation A (Bunny CDN as asset edge), B (multi-PoP self-host), or C (accept latency)?
4. **DDoS posture** — Is OVH-edge €60/yr worth it? Alternative: skip OVH, run Pangolin on Netcup itself, accept volumetric exposure.
5. **Stack pick** — Stack 1 / 2 / 3 (recommend Stack 2)?
6. **Phase 3 (R2 → MinIO) gating** — Wait for TASK-66 hardware (recommended), or use temporary B2 destination?

---

## Recommendation

**Adopt Stack 2 (Pangolin + OVH edge + Netcup origin)** as the target. Begin with **Phase A (Authentik + CF Access swap)** as a low-risk first move that validates the bundle's identity layer.

**Defer Phase F (R2 → MinIO)** until TASK-66 hardware lands.

**Treat Phase H (bundle packaging)** as the proof — until the bundle deploys to a fresh VPS, the project is incomplete.

**Accept** Xero as a vendor exception, Figma as legacy-only, and ~$65/yr OVH cost as the price of DDoS protection.

**Re-evaluate** at the end of Phase A whether to commit to the full 16-week timeline or stop at the hybrid Stack 3 milestone.
