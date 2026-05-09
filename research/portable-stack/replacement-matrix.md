# Replacement Matrix — Vendor-Portable Stack Migration

**Task:** TASK-83 Phase 1
**Date:** 2026-05-08
**Inputs:** [dep-inventory.md](./dep-inventory.md)
**Goal:** For every P0/P1/P2 SaaS dependency, identify 2-3 OSS replacements with maturity scoring; pick primary + fallback per slot.

---

## Maturity scoring rubric

| Score | Criteria |
|---|---|
| **A** | >5y old, active commits in last month, >50 contributors, official Docker images, production-grade docs |
| **B** | 2-5y old, active maintenance, Docker support, used in production by others |
| **C** | <2y old OR thin maintenance, niche but viable |
| **D** | Experimental, hobby project, single maintainer, avoid for P0 |

---

## P0 slots

### Slot 1: Public ingress (replaces CF Tunnel + edge)

| Candidate | License | Maturity | Compose? | Notes |
|---|---|---|---|---|
| **Pangolin** [fosrl/pangolin](https://github.com/fosrl/pangolin) | AGPL-3.0 | **B** (2024+, ~6k★, active) | ✓ official | WireGuard tunnel + Traefik + web UI for ingress + identity. Closest 1:1 CF Tunnel replacement. Bundles a lot. |
| **frp** [fatedier/frp](https://github.com/fatedier/frp) | Apache-2.0 | **A** (2016+, 89k★, mature) | ✓ | Generic reverse tunnel, battle-tested. No web UI. Manual TOML config. |
| **rathole** [rapiz1/rathole](https://github.com/rapiz1/rathole) | Apache-2.0/MIT | **B** (2022+, 12k★) | ✓ | Rust rewrite of frp. Lighter, faster. Smaller ecosystem. |
| **WireGuard direct + public NIC** | GPL-2.0 | **A** | n/a | Skip the tunnel: give Netcup public IPv4 + WireGuard sidecar for admin. Origin exposed (no hiding). |

**Primary**: **Pangolin** — bundles the tunnel + edge proxy + access UI in one project, matches the CF Tunnel UX shape, AGPL forces upstream contribution.
**Fallback**: **frp** + Traefik + separate Authentik — more pieces, but A-grade maturity. Use if Pangolin proves immature for 447-service scale.

**Gotcha**: Pangolin's Newt agent uses outbound WireGuard from Netcup → edge VPS. Need a small edge VPS (€5/mo OVH/Hetzner) to run Pangolin server. CF Tunnel needs no edge node. This is real added cost + ops surface.

---

### Slot 2: Authoritative DNS (replaces CF DNS)

| Candidate | Type | Maturity | Cost | Notes |
|---|---|---|---|---|
| **Bunny DNS** [bunny.net/dns](https://bunny.net/dns/) | Managed | **A** | Free w/ CDN | Anycast (119 PoPs), DNSSEC, GeoDNS, REST API. Pairs with Bunny CDN if we use that for Slot 5. |
| **deSEC** [desec.io](https://desec.io/) | Managed (non-profit) | **A** | Free | EU non-profit, DNSSEC default, anycast, REST API, no payment ever. Privacy-aligned. |
| **Porkbun DNS** [porkbun.com](https://porkbun.com/) | Managed (registrar) | **A** | Free w/ domain | Already our registrar. Anycast, DNSSEC, solid API. Caddy/Lego ACME plugin. |
| **PowerDNS + 2 secondary servers** | Self-hosted | **A** | VPS cost | Full sovereignty. Need 2-3 geographic replicas + DNSSEC management. Real ops burden. |

**Primary**: **deSEC** — non-profit, DNSSEC default, free forever, anycast. Best vendor-portable choice for ideological independence. API is clean.
**Fallback**: **Porkbun DNS** — already paying for the registrar, zero new vendor surface, API works with our existing ACME setup.

**Gotcha**: Self-hosted PowerDNS rejected for now — DNS is the one infra layer where managed anycast genuinely beats self-hosted (latency-sensitive, glue-record dance, DNSSEC key rotation). Revisit only if "fully sovereign" hardens later.

---

### Slot 3: TLS certs (already vendor-portable)

| Candidate | Notes |
|---|---|
| **Let's Encrypt** | Current default. Works via DNS-01 with deSEC/Porkbun/Bunny modules. |
| **ZeroSSL** | Drop-in ACME alternative. Same wire protocol. |
| **Buypass** | 180-day certs, ACME, EU-based. |
| **smallstep step-ca** [smallstep.com/cli](https://github.com/smallstep/cli) | Self-hosted ACME CA for *internal* services. Public services still need a public CA. |

**Primary**: **Let's Encrypt** via Traefik's built-in ACME.
**Fallback**: **ZeroSSL** — same protocol, just swap the CA URL in Traefik config.
**Internal services**: **step-ca** for cluster-internal mTLS if Phase 4 hardens further.

No real change needed here — already standards-based.

---

## P1 slots

### Slot 4: Identity / Zero-trust auth (replaces CF Access)

| Candidate | License | Maturity | Compose? | Notes |
|---|---|---|---|---|
| **Authentik** [goauthentik.io](https://goauthentik.io) | MIT | **A** (2020+, 14k★, prolific) | ✓ official | Full IdP — OIDC, SAML, LDAP, forward-auth. Heaviest. Best feature parity with CF Access. |
| **Authelia** [authelia.com](https://www.authelia.com) | Apache-2.0 | **A** (2017+, 23k★) | ✓ | Forward-auth + 2FA only. No full IdP. Lighter. |
| **Pocket-ID** [pocket-id/pocket-id](https://github.com/pocket-id/pocket-id) | MIT | **C** (2024+, 8k★, fast-growing) | ✓ | Passkey-only OIDC. Minimalist. Not for SAML/LDAP. |
| **Keycloak** [keycloak.org](https://www.keycloak.org/) | Apache-2.0 | **A** (2014+, RH-backed) | ✓ | Enterprise IdP. Java, heavy, overkill for solo ops. |

**Primary**: **Authentik** — best CF Access parity, real IdP, supports forward-auth via Traefik middleware, federates with Headscale via OIDC if needed.
**Fallback**: **Pocket-ID** — if Authentik proves too heavy ops-wise. Passkeys-only is fine for an admin-of-one.

**Gotcha**: CF Access auto-injects identity headers downstream; Authentik forward-auth does the same via `X-Forwarded-User` / `Remote-Email`. Apps that read CF-specific headers (`Cf-Access-Authenticated-User-Email`) need a one-line config swap.

---

### Slot 5: Object storage (replaces CF R2)

| Candidate | License | Maturity | API | Cost |
|---|---|---|---|---|
| **MinIO** [min.io](https://min.io/) | AGPL-3.0 (community), commercial | **A** | S3 | self-host, disk only |
| **Garage** [garagehq.deuxfleurs.fr](https://garagehq.deuxfleurs.fr/) | AGPL-3.0 | **B** (2020+, geo-distributed by design) | S3 | self-host |
| **SeaweedFS** [seaweedfs.com](https://github.com/seaweedfs/seaweedfs) | Apache-2.0 | **A** (10y+) | S3 + custom | self-host |
| **Backblaze B2** | proprietary | **A** | S3 | $6/TB/mo, free egress to CF/Bunny — bridges nicely |
| **Hetzner Object Storage** | proprietary | **B** (2024 launched) | S3 | €5.99/TB/mo |

**Primary**: **MinIO** on local disks (post-TASK-66 hardware). S3 API = drop-in replacement for R2 in `r2-mount` rclone config.
**Fallback (managed)**: **Backblaze B2** — vendor-portable via S3 API, no egress fees to friendly CDNs, $6/TB/mo. Use if local hardware not yet provisioned.

**Gotcha**: Plex/Jellyfin media currently in `r2:plex-media` — egress cost from R2 to wherever we land it is one-time but real (CF R2 free egress only to CF; non-CF egress is $0.015/GB → for 5TB media library = $75 one-time hit). Schedule the migration AFTER MS-S1 Max disks land (TASK-66) to avoid double-paying.

---

### Slot 6: WAF (replaces CF WAF)

| Candidate | License | Maturity | Notes |
|---|---|---|---|
| **BunkerWeb** [bunkerity/bunkerweb](https://github.com/bunkerity/bunkerweb) | AGPL-3.0 | **B** (2021+, 7k★, active) | nginx + ModSecurity + CRS + custom rules. Best self-host. |
| **Coraza** [coraza.io](https://coraza.io/) | Apache-2.0 | **A** (OWASP project) | ModSecurity rewrite in Go. Library. Caddy + Traefik plugins. |
| **CrowdSec** [crowdsec.net](https://crowdsec.net/) | MIT | **A** | Behavioral IDS + community-shared blocklists. Complement, not replacement, for ModSecurity. |
| **SafeLine** [chaitin/SafeLine](https://github.com/chaitin/SafeLine) | Apache-2.0 | **B** | Semantic engine, China-origin. UI is nice. |

**Primary**: **Coraza** as Traefik middleware — keeps Traefik in control plane, no nginx layer added.
**Complement**: **CrowdSec** — behavior-based IP blocking, syncs with global threat intel. Cheap insurance.

**Gotcha**: Coraza Traefik plugin is in [traefik-plugins-registry](https://plugins.traefik.io/) but version <1.0 — may need version pinning. BunkerWeb is more turnkey but adds nginx-in-front-of-Traefik (extra hop, complicates compose).

---

### Slot 7: DDoS protection (partly irreplaceable)

**Honest take**: nothing free matches CF's Tbps anycast scrubbing. Single-VPS volumetric protection requires moving to a host that bundles it.

| Candidate | Cost | Coverage |
|---|---|---|
| **OVH VPS** [ovhcloud.com/anti-ddos](https://www.ovhcloud.com/en/security/anti-ddos/) | €5/mo VPS, free unmetered DDoS protection | L3/L4 + some L7 |
| **Gcore CDN free tier** [gcore.com](https://gcore.com/cdn) | Free 1TB/mo, includes DDoS | L7 + scrubbing |
| **Stay on Netcup + Coraza + CrowdSec** | $0 marginal | L7 only — useless vs volumetric |
| **Bunny.net Shield** | $10/mo | Edge WAF + rate limits |

**Primary**: **Move public edge to OVH VPS** running Pangolin (Slot 1). OVH bundles real DDoS scrubbing free with all VPS. Origin (Netcup) stays unreachable directly.
**Complement**: **CrowdSec** at origin for L7 abuse.

**Gotcha**: This means the bundle has 2 VPS in production: edge (OVH) + origin (Netcup). Single-VPS deploy of the bundle still works without OVH but loses real DDoS protection — document the trade-off in `bundle-design.md` Phase 2.

---

## P2/P3 slots — MCP SaaS

### Slot 8: Image/video AI generation (replaces fal-ai, runpod-image-gen)

| Candidate | License | Maturity | Notes |
|---|---|---|---|
| **ComfyUI** [comfyanonymous/ComfyUI](https://github.com/comfyanonymous/ComfyUI) | GPL-3.0 | **A** (de facto standard) | Node-graph UI, every SDXL/Flux model, API mode. Needs GPU. |
| **AUTOMATIC1111 / sd-webui** | AGPL-3.0 | **A** | Older, simpler. ComfyUI is winning. |
| **OpenWebUI + diffusion plugins** | MIT | **B** | Less specialized but unifies LLM+image. |

**Primary**: **ComfyUI** in API mode, runs on TASK-66 hardware (Strix Halo iGPU has 96GB unified memory — viable for SDXL/Flux). Local MCP shim wraps the API.
**Fallback (cloud burst)**: keep RunPod's ComfyUI template available for spikes.

---

### Slot 9: Vision/multimodal LLM (replaces Gemini MCP)

| Candidate | Notes |
|---|---|
| **Llama 3.2 Vision** via Ollama | Already have Ollama. 11B vision model fits Strix Halo. |
| **Qwen2-VL via vLLM** | Higher quality, RunPod or local. |
| **Pixtral via Ollama** | Mistral's multimodal. |

**Primary**: **Llama 3.2 Vision (11B)** via existing Ollama after TASK-66 (current Netcup CPU can't run vision usefully).
**Fallback**: keep Gemini MCP available but mark deprecated — only used when local fails.

---

### Slot 10: Calendar (replaces Google Calendar MCP)

| Candidate | License | Notes |
|---|---|---|
| **Radicale** [radicale.org](https://radicale.org/) | GPL-3.0 | **A** | Lightweight CalDAV/CardDAV server. Single Python file, basically. |
| **SOGo** (already in Mailcow) | GPL | **A** | Already running inside Mailcow. CalDAV exposed on `:443/SOGo/dav/`. Free. |

**Primary**: **SOGo via Mailcow** — already deployed, no new container. Configure clients to use `https://mail.rmail.online/SOGo/dav/<user>/Calendar/`.
**MCP shim**: write a small CalDAV MCP server (or fork existing one) to replace the Google Calendar MCP.

---

### Slot 11: Accounting (Xero) — no realistic OSS replacement

**Honest assessment**: Xero's value is the bank-feed integrations + jurisdiction-specific tax modules + accountant ecosystem. None of those have OSS replacements at quality.

| Candidate | Notes |
|---|---|
| **Akaunting** [akaunting.com](https://akaunting.com/) | Open-core. Lacks bank feeds. |
| **Manager.io** | Free desktop, not multi-user, no API. |
| **InvoicePlane** | Invoicing-only, not full ledger. |

**Recommendation**: **keep Xero**, but treat the MCP server as a *read-only reporting* surface so the lock-in stays at the service boundary, not the workflow boundary. Document Xero as an accepted exception in `bundle-design.md`.

---

### Slot 12: Design (Figma) — partial replacement only

| Candidate | License | Notes |
|---|---|---|
| **Penpot** [penpot.app](https://penpot.app/) | MPL-2.0 | **B** (mature enough, growing fast) | Self-hostable, Docker Compose, real Figma alternative for new work. |

**Recommendation**: **Penpot for new design work**, keep Figma for existing files (export not lossless). Figma MCP becomes optional.

---

## Backups — gap to fill in Phase 2

Phase 0 found `db-backup-cron` running but couldn't confirm destination. Phase 2 must:
1. Inspect the cron container's actual script
2. Identify whether backups go to local disk, CF R2, or elsewhere
3. Add **restic** + **rclone** to the bundle with parameterized backend (S3-any, B2, local)

| Candidate | Notes |
|---|---|
| **restic** [restic.net](https://restic.net/) | **A** | Encrypted, deduplicating. S3/B2/local/SFTP backends. Standard. |
| **borg** | **A** | Encrypted, deduplicating. Older, similar. SSH-pull model. |
| **Kopia** | **B** | Newer, web UI. |

**Primary**: **restic** — most active, cleanest CLI, every backend imaginable.

---

## Summary — primary picks

| Slot | Primary | Fallback | Status |
|---|---|---|---|
| Tunnel/edge | **Pangolin** | frp + Traefik + Authentik | new ingress |
| DNS | **deSEC** | Porkbun DNS | move NS |
| TLS | Let's Encrypt (no change) | ZeroSSL | already done |
| Identity | **Authentik** | Pocket-ID | new IdP |
| Object storage | **MinIO** (post-TASK-66) | Backblaze B2 | data migration |
| WAF | **Coraza** Traefik plugin | BunkerWeb | new middleware |
| DDoS | **OVH edge VPS** running Pangolin | CrowdSec only | new infra |
| Image AI | **ComfyUI** local | RunPod ComfyUI burst | post-TASK-66 |
| Vision LLM | **Llama 3.2 Vision** via Ollama | Gemini (deprecated) | post-TASK-66 |
| Calendar | **SOGo via Mailcow** | Radicale | already running |
| Accounting | Xero (accepted vendor exception) | — | no migration |
| Design | **Penpot** (new work) | Figma (legacy files) | new tool |
| Backups | **restic** | borg | Phase 2 audit needed |

## What this matrix does NOT decide

- The order of cutover (Phase 3)
- The compose topology (Phase 2)
- The TCO comparison (Phase 4)
- Whether OVH-edge cost is worth it for a homelab — depends on threat model (Phase 4)
