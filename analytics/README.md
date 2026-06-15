# Privacy Analytics — Umami + Analytics Hub

Privacy-first (cookieless, no PII, no consent banner) web analytics across all
sites, with a single network-wide rollup dashboard.

- **Platform:** Umami v3.0.3 — `https://analytics.rspace.online` (tracker: `collect.js`)
- **Hub:** `analytics-hub` container on Netcup — network-wide rollup over Umami's Postgres (read-only)
- **Source of truth:** [`site-registry.yaml`](site-registry.yaml) — domain → website_id → repo

## ⚠️ Status note (2026-06-15)
Umami collection went silent on **2026-02-25** (only 215 events ever; the rStack
snippet stopped firing). The pipeline itself is verified healthy (`collect.js`
serves 200, `/api/send` ingests). Data resumes once the snippet is (re)deployed
to live sites.

---

## How it works
1. Each site loads one tag: `snippet.html` with its `data-website-id`.
2. Umami ingests hits into Postgres (`website_event`, `session`).
3. The hub reads Postgres via the **`umami_ro`** role (SELECT-only) and aggregates
   visitors / pageviews / trend + top sites + referrers + organic search + UTM +
   countries across every website.

## Rollout — adding analytics to a site
1. Find the site's `website_id` in `site-registry.yaml` (already minted for 22 sites).
   - New site? add it to `mint.sql`, re-run (idempotent), add a row here.
2. Deliver the tag:
   - **Env-driven apps** (Next/Bun, like rspace): set in the site's compose
     `UMAMI_URL=https://analytics.rspace.online` and `UMAMI_WEBSITE_ID=<id>`; the app emits the tag.
   - **Static sites:** inject the `<head>` tag (idempotent helper):
     ```bash
     # on Netcup, against the served HTML
     ./inject-snippet.sh <website_id> /opt/websites/<site>/<index-or-head>.html
     ```
   - **Discourse** (p2pforum): Admin → Customize → Themes → `</head>` section.
   - **Forgejo** (forgejo-peer): `custom/templates/custom/header.tmpl`.
3. Redeploy the site. Flip `wired: true` in `site-registry.yaml`.
4. Verify: load the page, then check the hub or
   `SELECT count(*) FROM website_event WHERE website_id='<id>' AND created_at > now()-interval '10 min';`

## Minting website IDs
```bash
cat mint.sql | ssh netcup-full 'docker exec -i umami-db psql -U umami -d umami'
```
Idempotent on domain; prints the full domain→website_id mapping.

---

## The Hub

`hub/` — FastAPI + asyncpg, single-page dashboard (`/`), JSON at `/api/summary?days=7|30|90`.
Deployed at `/opt/apps/analytics-hub` on Netcup.

### Access (live)
- **Public:** https://stats.jeffemmett.com — Traefik **basic-auth** (user `jeff`).
  DNS CNAME → tunnel `a838e9dc…`; tunnel ingress → Traefik (`web`); router `stats`
  + middleware `stats-auth` (apr1 hash in compose labels, `$` doubled for compose).
  Rotate pw: `openssl passwd -apr1 <pw>`, double every `$`, update the
  `traefik.http.middlewares.stats-auth.basicauth.users` label, `docker compose up -d`,
  then `docker restart traefik` (label hot-reload is unreliable — restart to register).
- **Tailscale:** also http://100.64.0.2:8899 (UFW `allow in on tailscale0 ... 8899/tcp`).
- `dashboard.jeffemmett.com` is NOT us — it's the separate `personal-dashboard` app.

### Make it public (needs zone-edit CF token — NOT in ~/.cloudflare-credentials.env)
The dashboard exposes all sites' analytics → **must sit behind Cloudflare Access.**
1. DNS: CNAME `analytics-hub.jeffemmett.com` → `a838e9dc-0af5-4212-8af2-6864eb15e1b5.cfargotunnel.com` (proxied).
2. Tunnel ingress: PUT a new entry `{hostname:"analytics-hub.jeffemmett.com", service:"http://localhost:80"}`
   before the catch-all (tunnel `a838e9dc…`, account `0e7b3338…`). Traefik labels already route it.
3. Cloudflare Access: create an Access app for the hostname + an allow policy (e.g. email = jeff@).

### Rebuild / redeploy hub
```bash
scp hub/{app.py,requirements.txt,Dockerfile,docker-compose.yml} netcup-full:/opt/apps/analytics-hub/
ssh netcup-full 'cd /opt/apps/analytics-hub && docker compose up -d --build'
```

### Rotate the read-only DB role
```sql
ALTER ROLE umami_ro PASSWORD '<new>';
```
Then update `DATABASE_URL` in `/opt/apps/analytics-hub/.env` and `docker compose up -d`.
`.env` is gitignored; `.env.example` documents the shape.

## Files
| File | Purpose |
|------|---------|
| `site-registry.yaml` | Source of truth: domain → website_id → repo → wired? |
| `mint.sql` | Idempotent website-ID minting |
| `snippet.html` | Canonical tracker tag |
| `inject-snippet.sh` | Idempotent `<head>` injector for static sites |
| `hub/` | Network rollup dashboard (FastAPI, read-only Postgres) |
