# Architecture: Multi-Location Failover

## Network Topology

```
Internet
  │
  ├── Cloudflare DNS (health-check routing)
  │     ├── Primary: Netcup Cloudflare Tunnel
  │     └── Failover: Local NAS Cloudflare Tunnel
  │
  ├── Netcup RS 8000 (Frankfurt) ──── Headscale coordinator
  │     ├── Traefik (reverse proxy)
  │     ├── rSpace + PostgreSQL (primary)
  │     ├── EncryptID + PostgreSQL (primary)
  │     ├── rInbox + PostgreSQL + Redis (primary)
  │     ├── Infisical (secret management)
  │     ├── LiteLLM (AI gateway)
  │     ├── Meeting Intelligence
  │     ├── Docmost, Twenty CRM, Postiz...
  │     └── Restic → R2 (backup)
  │
  └── Local NAS (Home, via Tailscale)
        ├── Traefik (standby, dormant Cloudflare Tunnel)
        ├── rSpace + PostgreSQL (streaming replica)
        ├── EncryptID + PostgreSQL (streaming replica)
        ├── rInbox + PostgreSQL (streaming replica)
        ├── Jellyfin + *arr stack (active, local media)
        ├── NAS storage (20-72TB RAID)
        └── Restic → R2 (independent backup)
```

## Failover Flow

1. Cloudflare health check pings Netcup endpoints every 30s
2. If 3 consecutive failures (90s), Cloudflare routes DNS to local tunnel
3. Local Traefik activates, PostgreSQL replicas promote to primary
4. Services resume on local server (degraded: no LiteLLM, no Meeting Intelligence)
5. Alert email sent to jeff@
6. When Netcup recovers: manual failback (re-sync data, switch DNS back)

## PostgreSQL Replication

```
Netcup (Primary)                    Local NAS (Standby)
┌──────────────┐                    ┌──────────────────┐
│ PostgreSQL   │ ── WAL stream ──▶  │ PostgreSQL       │
│ (read/write) │    via Tailscale   │ (read-only)      │
│              │                    │                  │
│ pg_hba.conf: │                    │ recovery.conf:   │
│ host repl    │                    │ primary_conninfo │
│   replica    │                    │ = host=netcup    │
│   10.x.x.x  │                    │   port=5432      │
└──────────────┘                    └──────────────────┘
```

Databases replicated:
- rSpace PostgreSQL (~10GB)
- EncryptID PostgreSQL (~2GB)
- rInbox PostgreSQL (~5GB)

## Storage Layout (Local NAS)

```
/
├── /boot          (NVMe, 500MB)
├── /              (NVMe, 1TB SSD)
│   ├── /var/lib/docker/     Docker volumes + images
│   ├── /var/lib/postgresql/  Streaming replicas
│   └── /opt/backup/          Restic cache
│
└── /mnt/nas       (HDD array, RAID1 or RAID10)
    ├── /mnt/nas/media/
    │   ├── movies/
    │   ├── shows/
    │   ├── music/
    │   └── downloads/
    ├── /mnt/nas/backups/
    │   ├── restic-repo/     Local Restic repository
    │   ├── db-dumps/        Nightly database dumps from Netcup
    │   └── keepass/         KeePass vault copies
    └── /mnt/nas/shared/     General NAS file sharing (Samba/NFS)
```

## Services: What Runs Where

| Service | Netcup (Primary) | Local NAS (Failover) | Notes |
|---------|:-:|:-:|-------|
| Traefik | Active | Standby | Activates on failover |
| rSpace | Active | Hot standby | Streaming replication |
| EncryptID | Active | Hot standby | Streaming replication |
| rInbox | Active | Hot standby | Streaming replication |
| Jellyfin | Active (remote) | **Active (local)** | Local = direct play, no buffering |
| Sonarr/Radarr/Lidarr | Active | Active | Manages local media |
| qBittorrent | Active | Active | Downloads to local NAS |
| Infisical | Active | Cold backup | Config backup only |
| LiteLLM | Active | Not replicated | Non-critical for failover |
| Meeting Intelligence | Active | Not replicated | Heavy resource, skip |
| Docmost | Active | Not replicated | Can restore from backup |
| Twenty CRM (5x) | Active | Not replicated | Admin-only |
| Postiz (4x) | Active | Not replicated | Batch, non-critical |

## Multi-Location Deployment

Each location needs:
- Hardware (mini PC + storage, scaled to role)
- Internet connection (any speed for backup-only; 50+ Mbps up for failover)
- Power (UPS recommended)
- Tailscale installed and joined to Headscale mesh

### Node Roles

| Role | Hardware | Monthly Cost | Purpose |
|------|----------|-------------|---------|
| **Full failover** | K8 Plus + 20TB NAS + UPS | ~$20 electricity | All capabilities |
| **Backup only** | Raspberry Pi 5 + USB HDD | ~$5 electricity | Restic + DB dump target |
| **Media node** | Any PC + large HDD | ~$10 electricity | Local Jellyfin at another location |

### Adding a New Node

```bash
# On the new machine:
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --login-server https://hs.jeffemmett.com

# Clone setup repo:
git clone https://gitea.jeffemmett.com/jeff/dev-ops.git
cd dev-ops/backup-NAS/setup

# Run setup for desired role:
./01-base-install.sh              # Always required
./03-backup-target.sh             # For backup-only nodes
# OR
./01-base-install.sh && ./02-storage-setup.sh && ./03-backup-target.sh \
  && ./04-media-server.sh && ./05-warm-standby.sh  # Full node
```

## Holon Isolation Layer (TASK-90, Phase 0 — design)

Status: **paper design**. Phases 1-4 gated on hardware (TASK-66). This section
is the Phase-0 deliverable.

### Why

Every May-2026 Netcup incident — ofelia OOM, the vaultwarden CF-flap, the
5-day bouncer death, gitea OOM — has the *same* root cause: ~389 containers on
one 64 GB VPS with zero isolation and no failover. Virtualization is the
missing **isolation + failover substrate**. It is not a capacity creator; it
buys blast-radius containment and a real standby target.

The payoff is specific to this hardware: the MS-S1 Max CPU (Ryzen AI Max+ 395)
supports **AMD SEV-SNP**, which is the native hardware primitive for the JMMJ
`tee-bound` / `tee` envelope tier. `shared/jmmj/holon-envelope.ts` already
names "AMD SEV" for `tee-bound` transport and `tee` compute — today those are
advisory string tags; on this box they become **hardware-enforced**.

A *holon* = one VM or LXC with an explicit resource + trust envelope that
mirrors `HolonEnvelope`. The hypervisor scheduler becomes the infra-layer
**Mercury**: it places and migrates holons according to their envelope.

### Non-goal (do not skip)

**The Netcup RS 8000 is NOT virtualized.** It is itself a KVM guest; nesting
a hypervisor inside it is fragile (nested virt, no clean passthrough) and is
pure negative value on a memory-starved box. This design applies **only** to
the local TASK-66 node and any future homelab hardware. The Netcup fix stays
what it is: tighter `mem_limit`s + OOM tiers + shedding idle services.

### Hypervisor decision

**Incus** (the LXD successor) for the single TASK-66 node. Rationale:
lightweight, fully scriptable, does both system containers (LXC) and full VMs
from one API, and the workload is mostly containers with a few isolation VMs —
which is exactly Incus's sweet spot. Proxmox VE's value (HA UI, clustering,
mature SEV-SNP tooling) only pays off with ≥2 nodes.

Revisit when the second MS-S1 unit is clustered (TASK-66 notes a 256 GB
2-unit path): at that point evaluate **Proxmox VE** for the cluster, or Incus
cluster mode if its HA story is sufficient by then.

### SensitivityTier → isolation primitive

| `SensitivityTier` | Isolation primitive | Morpheus storage mapping |
|---|---|---|
| `public` | Shared LXC, no special isolation (dense, cheap) | IPFS plaintext |
| `metadata-only` | Unprivileged/namespaced LXC | relay w/ metadata stripping |
| `encrypted` | Dedicated VM, encrypted ZFS dataset | IPFS ciphertext + per-recipient KEM |
| `zk-attested` | Dedicated VM + zk-proof sidecar container | MPC fragments |
| `tee-bound` | **AMD SEV-SNP confidential VM** — RAM encrypted, never hits disk plaintext | enclave-only, not pinned |

### ComputeTier → runtime placement

| `ComputeTier` | Placement on the node |
|---|---|
| `js-shared` | Shared LXC — the dense default-majority holon |
| `rust-sidecar` | Dedicated LXC/VM for rust-sidecar workloads (`trust-engine-rs`, `settlement-rs`, `janus-knn-rs`) — perf isolation |
| `tee` | SEV-SNP confidential VM (same box, hardware-backed) |
| `zk-circuit` | Roadmap — separate node/coprocessor, **not** this hardware |

Compute tier is orthogonal to sensitivity: it picks the runtime, not the
protection. A `js-shared` + `encrypted` quantum runs JS inside a dedicated
encrypted VM; a `tee` + `tee-bound` quantum runs in SEV-SNP.

### SEV-SNP feasibility on Ryzen AI Max+ 395 — to validate in Phase 1

Open questions to close before relying on the `tee-bound` row (document the
answer even if the conclusion is "defer"):

- Zen 5 / Ryzen AI Max+ 395 SEV-SNP enablement in BIOS (Minisforum firmware
  exposes the toggle?) and required `SNP`/`SEV` kernel cmdline on Ubuntu 24.04.
- Incus confidential-VM support maturity for AMD SEV-SNP (vs the more-trodden
  Intel TDX path) at install time.
- Attestation chain: can a holon prove its SEV-SNP measurement to Mercury so
  the envelope dispatcher trusts the `tee-bound` placement, or is that
  roadmap and we accept "isolated VM, unattested" as the interim tier?

Fallback if SEV-SNP isn't production-ready on this silicon: `tee-bound`
degrades to "dedicated encrypted VM, no remote attestation" — still a real
isolation upgrade over the current shared-container state.

### Failover interplay (ties TASK-66 AC#8-10)

The holon layer and the warm-standby role share the box; they must not
double-count the 128 GB:

- Standby holons run **cold or hot per the Services table above**. Hot
  standbys (rSpace / EncryptID / rInbox) are LXC holons receiving Postgres
  streaming replication — sized for *replication lag*, not full active load.
- On Netcup failover, Mercury (the scheduler) **promotes** the relevant
  standby holons (raise CPU/RAM envelope, flip Traefik active) and
  **suspends** non-critical local holons (media, batch) to reclaim RAM. The
  envelope makes this a declarative resize, not a manual scramble.
- Net effect: the same single-point-of-failure that produced this month's
  incidents becomes graceful degradation — a Netcup OOM storm sheds Tier-3
  holons here instead of cascading.

### Migration + rollback path

Order of moving Netcup services into local holons (lowest blast radius first):

1. **Backup/standby only** — no traffic cutover. Postgres streaming repl into
   `encrypted`-tier VM holons. Rollback = stop replication, delete holon.
2. **Media node** — Jellyfin already runs local-active per the Services
   table; formalize it as a `public` LXC holon. Rollback = point clients back
   at the remote.
3. **One stateless service** (e.g. a Postiz worker) into a `js-shared` holon
   behind the same Traefik+CF path, 10% traffic via weighted DNS. Rollback =
   revert DNS weight.
4. **tee-bound PoC** — the split-inference sensitive local-Ollama stage
   (see `split_inference_v0`) into a SEV-SNP holon; only sharded/frontier-safe
   work crosses the boundary. Rollback = feature-flag back to the non-isolated
   path; no data migration since the sensitive stage is ephemeral by design.

Every step is independently reversible and none requires touching Netcup
until its standby holon has demonstrated parity.
