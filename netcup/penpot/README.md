# Penpot deploy (penpot.jeffemmett.com)

Self-hosted open-source Figma/Sketch alternative — the interactive-design vertical.
Sablier scale-to-zero: whole stack stops when idle (~1.2-1.7 GB reclaimed), wakes
on the first request (~30-60s cold start: Postgres + backend JVM).

Stack: frontend (nginx) · backend (Clojure/JVM) · exporter (Chromium) · postgres:15 · valkey:8.1.
Deploy path on Netcup: `/opt/services/penpot/`.

## 1. Secrets + first deploy

```bash
ssh netcup-full
mkdir -p /opt/services/penpot && cd /opt/services/penpot
# copy docker-compose.yml + .env.example here (scp from dev-ops/netcup/penpot/)
cp .env.example .env
{ echo "PENPOT_SECRET_KEY=$(openssl rand -hex 32)";
  echo "POSTGRES_PASSWORD=$(openssl rand -hex 24)"; } > .env
chmod 600 .env
docker compose pull
docker compose up -d        # first boot runs DB migrations (~30-60s)
docker compose logs -f penpot-backend   # wait for "ready" / accepting connections
```

## 2. Traefik route + Sablier

```bash
# file-provider route (survives Sablier stopping the stack)
scp dev-ops/netcup/traefik/config/sablier-penpot.yml \
    netcup-full:/root/traefik/config/sablier-penpot.yml
```
The container labels already carry `sablier.enable`/`sablier.group=penpot`/
`traefik.enable=false`, so the file provider is the only route source.

## 3. Cloudflare tunnel DNS

Adding a hostname to the Netcup CF tunnel needs BOTH a DNS route AND an API
ingress update (route-dns alone is necessary-but-not-sufficient — see
dev-ops memory `cf_tunnel_remote_ingress`):

```bash
cloudflared tunnel route dns <TUNNEL_ID> penpot.jeffemmett.com
# then PUT the hostname into the tunnel's remote ingress config via the CF API
# (mirror an existing *.jeffemmett.com forge entry; origin = http://traefik:80
# with Host header preserved).
```

## 4. First user (registration is DISABLED)

`disable-registration` is set (public endpoint). Create users via the backend CLI:

```bash
docker exec -it penpot-backend ./manage.sh create-profile
#   prompts for name / email / password
# (older builds: ./manage.sh create-profile <fullname> <email>)
```

## 5. Verify

```bash
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
curl -s -A "$UA" -o /dev/null -w '%{http_code}\n' https://penpot.jeffemmett.com
# first hit after idle: a few seconds (Sablier wake), then 200 + the login UI
```

## Notes
- **Registration**: re-enable by swapping `disable-registration` out of
  `PENPOT_FLAGS` in both frontend + backend, or front the domain with CF Access.
- **Secrets**: `.env` is gitignored. Migrate to Infisical injection later
  (the entrypoint-wrapper pattern) — for now strong generated values in `.env`.
- **Backups**: penpot_postgres_v15 + penpot_assets volumes are auto-discovered
  by the /opt/backup-system restic job (postgres dump + volume).
- **Limits/OOM**: penpot-* is on the enforce-container-limits.sh SKIP list so
  the */5 cron doesn't clamp the JVM backend to 256m.
