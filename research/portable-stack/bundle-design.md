# Bundle Design — Vendor-Portable Stack

**Task:** TASK-83 Phase 2
**Date:** 2026-05-08
**Inputs:** [dep-inventory.md](./dep-inventory.md), [replacement-matrix.md](./replacement-matrix.md)
**Goal:** Define the Docker Compose bundle shape — topology, parameterized `.env` contract, bootstrap script outline, network diagram. The bundle deploys to a fresh VPS and serves a public HTTPS site with no Cloudflare in the path.

---

## Design principles

1. **One config swap per vendor** — every vendor-replaceable function is a `.env` knob, never code.
2. **Compose profiles for optionality** — DDoS edge, WAF, MinIO are *opt-in* via Compose profiles.
3. **Traefik stays** — label-driven Docker discovery is the killer feature; no payoff replacing it with Caddy.
4. **No state in the bundle** — bundle ships configs + compose; data lives in named volumes that survive `down/up`.
5. **Bootstrap is idempotent** — running `bootstrap.sh` twice should converge, not error.

---

## Topology

```
                              Internet
                                  │
                ┌─────────────────┴─────────────────┐
                │                                   │
        [optional edge VPS]              [direct mode — no edge]
        EDGE_MODE=pangolin               EDGE_MODE=direct
                │                                   │
        ┌───────▼────────┐                          │
        │ Pangolin server│                          │
        │  + Coraza WAF  │                          │
        │  (OVH/Hetzner) │                          │
        │  free DDoS L3/4│                          │
        └───────┬────────┘                          │
                │ WireGuard                         │ public IP:443
                │ (Newt agent)                      │
                ▼                                   │
        ┌────────────────────────────────────────────┐
        │            ORIGIN VPS (Netcup)             │
        │                                            │
        │  ┌──────────────────────────────────────┐  │
        │  │  Traefik v3                          │  │
        │  │  - ACME (LE/ZeroSSL/Buypass)         │  │
        │  │  - DNS-01 via ${DNS_PROVIDER}        │  │
        │  │  - Coraza middleware (if WAF=coraza) │  │
        │  │  - Authentik forward-auth on /admin  │  │
        │  └──────────┬───────────────────────────┘  │
        │             │                              │
        │  ┌──────────▼─────────┐  ┌──────────────┐  │
        │  │  Authentik         │  │  CrowdSec    │  │
        │  │  - OIDC/forward    │  │  - log tail  │  │
        │  │  - Postgres+Redis  │  │  - bouncer   │  │
        │  └────────────────────┘  └──────────────┘  │
        │                                            │
        │  ┌──────────────────────────────────────┐  │
        │  │  Application slot                    │  │
        │  │  (Mailcow / Gitea / Listmonk /       │  │
        │  │   Twenty / Discourse / 100+ apps)    │  │
        │  │  joins traefik-public network        │  │
        │  └──────────────────────────────────────┘  │
        │                                            │
        │  ┌──────────────────────────────────────┐  │
        │  │  Data layer                          │  │
        │  │  Postgres / MariaDB / Redis volumes  │  │
        │  └──────────────────────────────────────┘  │
        │                                            │
        │  ┌──────────────────────────────────────┐  │
        │  │  Storage (STORAGE_BACKEND)           │  │
        │  │  minio | b2-rclone | local-disk      │  │
        │  └──────────────────────────────────────┘  │
        │                                            │
        │  ┌──────────────────────────────────────┐  │
        │  │  Backups (restic)                    │  │
        │  │  → ${BACKUP_BACKEND}                 │  │
        │  └──────────────────────────────────────┘  │
        │                                            │
        │  ┌──────────────────────────────────────┐  │
        │  │  Observability                       │  │
        │  │  Uptime Kuma (existing) + Loki opt   │  │
        │  └──────────────────────────────────────┘  │
        └────────────────────────────────────────────┘

DNS path (independent of edge):
   ${BASE_DOMAIN} NS → ${DNS_PROVIDER}
   *.${BASE_DOMAIN} A → ${EDGE_PUBLIC_IP} (or ${ORIGIN_PUBLIC_IP} in direct mode)
```

---

## Compose layout

Multi-file with [Compose profiles](https://docs.docker.com/compose/profiles/) for optionality.

```
portable-stack/
├── .env.example                  # template, every knob documented
├── bootstrap.sh                  # idempotent first-run setup
├── docker-compose.yml            # base: Traefik, Authentik, CrowdSec
├── docker-compose.edge.yml       # profile: pangolin (Newt agent at origin)
├── docker-compose.storage.yml    # profile: minio
├── docker-compose.backups.yml    # always-on: restic sidecar
├── docker-compose.waf.yml        # profile: coraza (if not in base Traefik)
├── traefik/
│   ├── traefik.yml               # static config (entrypoints, providers, ACME)
│   ├── dynamic.yml               # middleware definitions (auth, rate-limit, headers)
│   └── acme.json                 # cert storage (volume-mounted)
├── authentik/
│   └── (config baked into image, blueprints in /authentik/blueprints/)
├── crowdsec/
│   ├── acquis.yaml               # log sources
│   └── parsers/
├── coraza/
│   └── crs-config.conf           # OWASP CRS tuning
├── restic/
│   ├── backup.sh                 # what to back up
│   └── prune-policy.env
└── apps/
    └── README.md                 # pattern for adding label-driven services
```

### Activation patterns

```bash
# minimal direct deploy (no edge, no WAF)
docker compose up -d

# production: edge tunnel + WAF + MinIO
docker compose --profile pangolin --profile coraza --profile minio up -d

# strictest: all profiles
docker compose --profile pangolin --profile coraza --profile minio --profile crowdsec up -d
```

---

## `.env` contract (all parameterized vendor knobs)

```dotenv
# ===== IDENTITY =====
BASE_DOMAIN=jeffemmett.com
ACME_EMAIL=jeff@jeffemmett.com

# ===== EDGE (DDoS hiding) =====
# direct = origin's public IP receives traffic directly
# pangolin = run Newt agent here, Pangolin server elsewhere
EDGE_MODE=direct
EDGE_PANGOLIN_SERVER_URL=
EDGE_PANGOLIN_TOKEN=

# ===== DNS =====
# desec | porkbun | bunny | cloudflare | route53
DNS_PROVIDER=desec
DNS_API_TOKEN=

# ===== ACME (TLS issuance) =====
# letsencrypt | zerossl | buypass
ACME_CA=letsencrypt
# dns01 (recommended) | http01
ACME_CHALLENGE=dns01

# ===== IDENTITY PROVIDER =====
# authentik | pocket-id | none
IDP_MODE=authentik
IDP_HOST=auth.${BASE_DOMAIN}
AUTHENTIK_SECRET_KEY=          # generated by bootstrap
AUTHENTIK_BOOTSTRAP_EMAIL=
AUTHENTIK_BOOTSTRAP_PASSWORD=  # generated by bootstrap, written to credentials file

# ===== WAF =====
# coraza | bunkerweb | none
WAF_MODE=coraza
CORAZA_RULESET_VERSION=4.7

# ===== DDoS / IDS =====
CROWDSEC_ENROLLMENT_KEY=        # optional, for community blocklist sharing

# ===== OBJECT STORAGE =====
# minio | b2 | hetzner | s3 | local-disk
STORAGE_BACKEND=minio
STORAGE_BUCKET=app-media
STORAGE_S3_ENDPOINT=http://minio:9000
STORAGE_S3_REGION=us-east-1
STORAGE_S3_ACCESS_KEY=
STORAGE_S3_SECRET_KEY=

# ===== BACKUPS =====
# restic-s3 | restic-b2 | restic-local | restic-sftp
BACKUP_BACKEND=restic-b2
BACKUP_REPO_URL=                # b2:bucket-name:/path
BACKUP_RESTIC_PASSWORD=         # generated by bootstrap, written to credentials file
BACKUP_B2_ACCOUNT_ID=
BACKUP_B2_ACCOUNT_KEY=
BACKUP_SCHEDULE=0 3 * * *       # cron, default 3am daily
BACKUP_RETENTION=--keep-daily 7 --keep-weekly 4 --keep-monthly 12

# ===== AI / LLM (vendor-portable) =====
# Pre-existing LiteLLM config, no change needed in bundle scope
LITELLM_BASE_URL=http://litellm:4000
RUNPOD_VLLM_BASE_URL=           # optional GPU burst, blank = local Ollama only
RUNPOD_VLLM_BEARER=

# ===== OPTIONAL VENDOR EXCEPTIONS (documented) =====
XERO_CLIENT_ID=                 # accepted vendor exception
XERO_CLIENT_SECRET=
```

---

## Vendor-swap matrix

How each `.env` change touches the system:

| Knob | Change effect | Downtime |
|---|---|---|
| `DNS_PROVIDER` | Update Traefik ACME provider plugin + re-issue certs (DNS-01 challenge against new provider) | 0 (LE re-issue is hot) |
| `ACME_CA` | Change Traefik `caServer` URL, force renewal | 0 |
| `EDGE_MODE` | Pangolin profile up/down, public IP records updated at DNS | ~30s while DNS TTL expires |
| `IDP_MODE` | Authentik profile down, Pocket-ID up, Traefik forward-auth URL change | ~1min for protected routes |
| `STORAGE_BACKEND` | rclone re-sync from old → new bucket; switch app `STORAGE_S3_ENDPOINT` | depends on data size |
| `WAF_MODE` | Coraza middleware enabled/disabled in Traefik dynamic config | 0 |
| `BACKUP_BACKEND` | New restic repo init at new backend; old repo retained until verified | 0 |

---

## Network architecture

Existing Netcup networks, preserved by bundle:

| Network | Purpose | External? |
|---|---|---|
| `traefik-public` | All services exposing HTTP routes via Traefik | external (existing) |
| `mailcowdockerized_mailcow-network` | Apps that send via Postfix container | external (Mailcow's) |
| `internal` | DB ↔ app, no external | internal-only |
| `bundle-edge` | Pangolin Newt ↔ Traefik | created by bundle |

Bundle rule: all new services join `traefik-public` for ingress + their own `internal` net for data. No service exposes ports directly to host.

---

## bootstrap.sh outline

```bash
#!/usr/bin/env bash
# Idempotent: re-running converges, doesn't error.
set -euo pipefail

# 1. Prereqs
require_cmd docker docker-compose dig curl jq openssl

# 2. Validate .env
source ./.env
require_var BASE_DOMAIN ACME_EMAIL DNS_PROVIDER

# 3. Generate one-time secrets if missing (writes to credentials/<name>)
generate_if_missing AUTHENTIK_SECRET_KEY    32-byte-base64
generate_if_missing AUTHENTIK_BOOTSTRAP_PASSWORD 24-char-pwd
generate_if_missing BACKUP_RESTIC_PASSWORD       32-char-pwd

# 4. DNS validation (does NOT auto-create — fail loud, instruct)
check_dns_record "${BASE_DOMAIN}" A "${PUBLIC_IP}" \
  || abort "create A record at ${DNS_PROVIDER}: @ → ${PUBLIC_IP}"
check_dns_record "auth.${BASE_DOMAIN}" A "${PUBLIC_IP}"
check_dns_record "*.${BASE_DOMAIN}" A "${PUBLIC_IP}"   # wildcard for app subdomains

# 5. Bring up core
docker compose up -d traefik
wait_for_acme_cert "${BASE_DOMAIN}"   # tail traefik logs for cert issuance

# 6. Bring up identity if requested
if [[ "${IDP_MODE}" != "none" ]]; then
  docker compose up -d authentik authentik-postgres authentik-redis
  wait_for_http "https://auth.${BASE_DOMAIN}/-/health/live/" 200
  if first_run; then
    apply_authentik_blueprints   # provision admin + initial OIDC clients
  fi
fi

# 7. Bring up profiles per .env
[[ "${EDGE_MODE}" == "pangolin" ]] && docker compose --profile pangolin up -d
[[ "${WAF_MODE}" == "coraza" ]]    && enable_traefik_middleware coraza
[[ "${STORAGE_BACKEND}" == "minio" ]] && docker compose --profile minio up -d

# 8. Smoke tests
smoke_https "https://${BASE_DOMAIN}/" 200
smoke_https "https://auth.${BASE_DOMAIN}/" 200
smoke_internal "http://traefik:8080/api/rawdata"

# 9. Backups
restic_init_if_needed
schedule_backup_cron

# 10. Report
print_credentials_path
print_next_steps
```

---

## Authentik forward-auth integration

Traefik middleware (in `traefik/dynamic.yml`):

```yaml
http:
  middlewares:
    authentik:
      forwardAuth:
        address: http://authentik-server:9000/outpost.goauthentik.io/auth/traefik
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-email
          - X-authentik-groups
```

Apps replace CF Access labels:
```diff
- traefik.http.routers.kuma.middlewares=cf-access-strip-headers@docker
+ traefik.http.routers.kuma.middlewares=authentik@file
```

For apps that read `Cf-Access-Authenticated-User-Email` directly, add a header rename middleware to map `X-authentik-email` → the legacy header. One-line, kept on the same route.

---

## Pangolin Newt agent (origin side)

When `EDGE_MODE=pangolin`:

```yaml
# docker-compose.edge.yml
services:
  newt:
    image: fosrl/newt:latest
    profiles: [pangolin]
    restart: unless-stopped
    environment:
      PANGOLIN_ENDPOINT: ${EDGE_PANGOLIN_SERVER_URL}
      NEWT_TOKEN: ${EDGE_PANGOLIN_TOKEN}
    networks:
      - traefik-public
    cap_add: [NET_ADMIN]
    devices: [/dev/net/tun]
```

Pangolin server runs on the edge VPS (€5/mo OVH). Bundle includes a `setup-edge.sh` that bootstraps Pangolin server on a fresh OVH instance — separate concern, separate compose stack.

---

## Cert + ACME wiring

Traefik static config:

```yaml
certificatesResolvers:
  default:
    acme:
      email: ${ACME_EMAIL}
      storage: /acme.json
      caServer: ${ACME_CA_URL}              # mapped from ACME_CA enum
      dnsChallenge:
        provider: ${DNS_PROVIDER}            # desec | porkbun | etc.
        delayBeforeCheck: 30
```

Lego (Traefik's ACME library) supports all our DNS providers natively — no custom plugin needed.

---

## State migration: where data lives

| Service | Volume | Bundle action |
|---|---|---|
| Traefik | `acme.json` | bind-mount, preserved |
| Authentik | `authentik-postgres-data`, `authentik-redis-data` | named volumes |
| MinIO | `minio-data` | named volume, can be backed by external block |
| Postgres/MariaDB (existing apps) | named volumes | unchanged |
| App-specific volumes | unchanged | bundle does not touch app data |

Bundle's responsibility: **infra layer** (ingress, identity, WAF, storage backend, backups). Existing app data stays put.

---

## Backups (restic) topology

```yaml
# docker-compose.backups.yml
services:
  restic:
    image: restic/restic:latest
    restart: unless-stopped
    environment:
      RESTIC_REPOSITORY: ${BACKUP_REPO_URL}
      RESTIC_PASSWORD: ${BACKUP_RESTIC_PASSWORD}
      B2_ACCOUNT_ID: ${BACKUP_B2_ACCOUNT_ID}
      B2_ACCOUNT_KEY: ${BACKUP_B2_ACCOUNT_KEY}
    volumes:
      - /var/lib/docker/volumes:/source:ro
      - ./restic/backup.sh:/backup.sh:ro
    entrypoint: ["/bin/sh", "/backup.sh"]
```

`backup.sh` runs on cron (host or in-container ofelia), iterates over volumes, dumps Postgres/MariaDB live, restic snapshot to backend.

---

## Phase 2 gaps to close in implementation

1. **Confirm `db-backup-cron` destination** before sun-setting it (might already be doing what restic would do)
2. **Identify which apps read `Cf-Access-*` headers** — needs `grep -r "Cf-Access" /opt/apps/` on Netcup
3. **Inventory which services need `traefik.enable=true` middleware swaps** for Authentik forward-auth
4. **Pangolin v1.0 readiness** — spec says "B" maturity in Phase 1; verify it has handled 100+ services in production somewhere

---

## What this design does NOT do

- Replace Traefik (kept — already works at scale)
- Replace Mailcow / Gitea / Infisical / Headscale (already self-hosted, out of scope)
- Run any LLM in the bundle — LiteLLM proxies external Ollama, kept as-is
- Solve the volumetric DDoS problem without a paid edge (single-VPS deploy still vulnerable)
- Migrate any data — this is design only, Phase 3 schedules the cutover
