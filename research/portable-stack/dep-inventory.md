# Dependency Inventory — Vendor-Portable Stack Migration

**Task:** TASK-83 Phase 0
**Date:** 2026-05-08
**Scope:** Every external dependency in the Netcup-hosted stack + Claude tooling. Confirms what's already self-hosted, surfaces remaining vendor lock-in, ranks migration targets by criticality.
**Method:** SSH inventory of running containers (447), cloudflared config, LiteLLM config, MCP server list, dev-ops repo scan, infrastructure context doc.

---

## Criticality scale

| Level | Meaning |
|---|---|
| **P0** | Single point of failure. Removing breaks public traffic or core ops. |
| **P1** | Important. Removing degrades service or breaks one product surface. |
| **P2** | Nice-to-have. Removing affects convenience workflows. |
| **P3** | Optional. Removing affects nothing critical. |

## Lock-in scale

| Level | Meaning |
|---|---|
| **HARD** | Vendor-specific protocol/data; switching requires data export + reconfiguration |
| **SOFT** | Standards-based; switching is a config swap |
| **NONE** | Already self-hosted or open-source-only |

---

## Tier 1 — External SaaS (migration targets)

| Dep | Function | Where | Criticality | Lock-in | Annual cost | Notes |
|---|---|---|---|---|---|---|
| **Cloudflare Tunnel** (`cloudflared.service`) | Public ingress for ALL 447 containers via single tunnel → localhost:80 → Traefik | Netcup host systemd | **P0** | HARD | $0 (free tier) | Tunnel ID `a838e9dc-0af5-4212-8af2-6864eb15e1b5`. Removing without replacement kills every public site. |
| **Cloudflare DNS** | Authoritative DNS for jeffemmett.com + most domains. Anycast resolvers. | Cloudflare | **P0** | SOFT | $0 (free tier) | Standards-based (NS records). Swap = move auth NS at registrar. CNAME to cfargotunnel.com creates coupling with Tunnel. |
| **Cloudflare Access** | Zero-trust auth on `/admin*` paths (Uptime Kuma status page, others) | Cloudflare | **P1** | HARD | $0 (free <50 users) | Identity provider tied to Google SSO. Replaceable with Authentik forward-auth. |
| **Cloudflare R2** (`r2-mount` rclone container) | Object storage for Plex/Jellyfin media (`r2:plex-media` → `/mnt/r2-media`) | Cloudflare | **P1** | SOFT (S3-compatible) | $0.015/GB/mo | Free egress to CF edge is the lock-in. Self-hosting needs disks (TASK-66 covers). |
| **Cloudflare WAF/DDoS** | L7 filtering + Tbps scrubbing at edge | Cloudflare | **P1** | NONE (passive) | $0 | Bundled with Tunnel. Genuinely irreplaceable on single VPS. |
| **RunPod GPU** | vLLM burst capacity for Qwen3-Coder-30B (`RUNPOD_VLLM_BASE_URL`) | RunPod | **P2** | SOFT (OpenAI-compat API) | usage-based | LiteLLM has Ollama fallback. TASK-66 supersedes (MS-S1 Max for local inference). |
| **MCP: Gemini** | Google Gemini 2.0 Flash via API key | Google AI | **P2** | HARD | usage-based | Used for image analysis, brainstorming. Replaceable with local Llama vision or Ollama. |
| **MCP: fal-ai** | Image/video generation API | Fal | **P2** | HARD | usage-based | Replaceable with self-hosted ComfyUI or Bunny Edge Scripting. |
| **MCP: runpod-image-gen** | RunPod image generation endpoint | RunPod | **P3** | SOFT | usage-based | Same pool as `RunPod GPU`. |
| **MCP: xero** | Accounting (OAuth, currently expired) | Xero | **P2** | HARD | sub fee | Business-critical. No realistic OSS replacement (ledger software exists but Xero ecosystem doesn't). |
| **MCP: figma** | Design tool API | Figma | **P2** | HARD | sub fee | Penpot is OSS alternative for design tool itself; no API parity. |
| **MCP: calendar** | Likely Google Calendar | Google | **P2** | HARD | $0 | Replaceable with own CalDAV (Radicale, SOGo via Mailcow). |
| **GitHub** | Public mirror of Gitea | GitHub | **P3** | SOFT | $0 | Auto-mirrored from Gitea. Optional — exists for discoverability only. |

## Tier 2 — External services, vendor-portable already

| Dep | Function | Where | Criticality | Lock-in | Notes |
|---|---|---|---|---|---|
| **Porkbun** | Domain registrar | Porkbun | **P0** | SOFT | Standards-based registrar. ICANN requires *some* registrar — vendor-portable. |
| **Let's Encrypt** | Public TLS CA via ACME | Let's Encrypt | **P0** | NONE | ACME is open standard. ZeroSSL/Buypass interchangeable. |
| **Netcup RS 8000** | VPS host for everything | Netcup | **P0** | NONE | Vendor-replaceable in principle but blast radius enormous. TASK-66 (MS-S1 Max) addresses physical sovereignty. |

## Tier 3 — Already self-hosted (no migration needed)

| Dep | Function | Container/Service | Confirmed |
|---|---|---|---|
| Mailcow | Full mail server (postfix, dovecot, rspamd, sogo) | `mailcowdockerized-*` (16 containers) | ✓ |
| Gitea + act_runner | Code hosting + CI | `gitea`, `gitea-runner`, `gitea-db` | ✓ v1.24.7 / runner v0.6.1 |
| Infisical | Secret management | `infisical`, `infisical-db`, `infisical-redis` | ✓ |
| Headscale | VPN coordination server (replaces tailscale.com control plane) | `headscale`, `headplane` | ✓ — Tailscale daemon connects to Headscale, not Tailscale Inc |
| Uptime Kuma | Status monitoring | `uptime-kuma` | ✓ 174+ monitors |
| Ollama | Local LLM inference | host systemd `ollama.service` | ✓ |
| LiteLLM | LLM proxy (routes to Ollama + RunPod) | `litellm`, `litellm-db` | ✓ |
| Traefik | Reverse proxy | `traefik` (v2.11) | ✓ |
| Vaultwarden | Team password manager | (deploying — TASK-82 in flight) | in progress |
| Listmonk | Newsletter sender | `listmonk*` (multiple instances) | ✓ |
| Postiz | Social media scheduler | `postiz-cc`, `postiz-p2pf` | ✓ |
| n8n | Workflow automation | `n8n`, `n8n-cosmolocal` | ✓ |
| Twenty CRM | CRM | `twenty-*` (multiple instances) | ✓ |
| Discourse | Forum | `app`, `p2pforum` | ✓ |
| MediaWiki | Wiki | `p2pwiki`, `p2pwikifr` | ✓ |
| Immich | Photos | `immich_*`, `rphotos_*` | ✓ |
| Jellyfin | Media server | `jellyfin`, `jefflix` | ✓ media on CF R2 (Tier 1 dep) |
| Directus | Headless CMS | `commons-hub-directus`, `katheryn-cms` | ✓ |
| Docmost | Wiki/docs | `docmost*` | ✓ |
| Affine | Notion alternative | `affine_*` | ✓ |
| Seafile | File sync | `seafile`, `seafile-db` | ✓ |
| Syncthing | P2P file sync | `syncthing` | ✓ |
| Umami | Web analytics (replaces Google Analytics) | `umami`, `umami-db` | ✓ |
| ERPNext | ERP | `erpnext-*` | ✓ |
| Hyperswitch | Payment routing | `payment-hyperswitch`, `hyperswitch-*` | ✓ |
| Receipt Wrangler | Expense tracking | `receipt-wrangler*` | ✓ |
| Navidrome | Music streaming | `navidrome` | ✓ |
| Open Notebook | LLM notebook | `open-notebook*` | ✓ |
| Sablier | On-demand container start/stop | `sablier` | ✓ |
| Temporal | Workflow engine | `temporal-shared-*` | ✓ |
| Qdrant | Vector DB | `semantic-search-qdrant` | ✓ |
| MCP: mailcow / litellm / memory / wireshark / osmmcp | Local MCP servers | various | ✓ |

**Total self-hosted services**: ~100+ application containers, 447 containers total including DBs/workers/redis/etc.

---

## Critical path analysis

**Removing Cloudflare without a replacement breaks**: 100% of public ingress (447 containers behind one tunnel). This is the load-bearing piece — everything else is downstream.

**Order of dependency**:
1. CF Tunnel → blocks all public traffic if removed
2. CF DNS → blocks domain resolution if removed (but Tunnel CNAME survives if NS is moved cleanly)
3. CF Access → blocks `/admin*` routes only
4. CF R2 → blocks Plex/Jellyfin media playback only
5. CF WAF/DDoS → degrades security posture but no immediate outage

**Migration must move Tunnel + DNS together** because the CNAME `@ → cfargotunnel.com` couples them. Any new ingress (Pangolin/Caddy/etc.) needs DNS pointing to the new edge.

---

## Surprises uncovered

1. **`r2-mount` exists** — Plex/Jellyfin media is in CF R2, not local disk. Egress cost when migrating media off R2 is the financial drag.
2. **Single-tunnel architecture** — every public-facing service routes through one cloudflared process. Operationally simple, but a replacement must handle the same fan-out (one ingress → Traefik → 447 services).
3. **No backup destination found** — `db-backup-cron` runs but its target is unclear. Possible CF R2 too. Phase 1 should confirm before designing.
4. **Tailscale-the-vendor is already gone** — Headscale runs the control plane; Tailscale daemon is just an OSS client. No migration needed for VPN.
5. **No Caddy or Pangolin yet** — Traefik does all reverse-proxy work. Bundle design can keep Traefik (label-driven Docker discovery) and only replace the *tunnel/edge* layer.
6. **MCP sprawl is small but real** — 6 of 11 MCP servers call SaaS APIs (Gemini, fal, runpod, xero, figma, calendar). Most are P2/P3 and replaceable individually.
7. **LiteLLM already has fallback chains** — every model alias has a local-Ollama fallback after RunPod. Vendor-portable LLM routing is mostly done.

---

## Inputs to Phase 1

The replacement matrix in Phase 1 must cover:
- **CF Tunnel** (P0)
- **CF DNS** (P0)
- **CF Access** (P1)
- **CF R2** (P1, depends on TASK-66 hardware)
- **CF WAF/DDoS** (P1, partly irreplaceable)
- **6 SaaS MCP servers** (P2/P3, individual swaps)
- **RunPod** (P2, TASK-66 supersedes)

Tier 2 deps (Porkbun, Let's Encrypt, Netcup) stay as configurable backends in the bundle — not removed, but parameterized so they can be swapped.

Tier 3 deps need no migration; bundle should preserve their current Docker Compose configurations as-is.
