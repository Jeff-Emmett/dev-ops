# Vaultwarden — self-hosted Bitwarden-compatible team password manager

| Status | Live |
|---|---|
| Personal vault | ✓ `passwords.jeffemmett.com` (deployed 2026-05-09) |
| Commons Hub vault | Deferred — pending `passwords.commons-hub.io` DNS |

Bitwarden's official browser extensions, mobile apps, and desktop apps all work against this self-hosted endpoint.

## Why these subdomains

- **`passwords.jeffemmett.com`** instead of `vault.jeffemmett.com` — the latter collides with the existing `yield-vault-backend` container
- **`passwords.commons-hub.io`** waits for that domain's DNS/zone to come online; instance scaffold is commented in `docker-compose.yml`, ready to uncomment

Each instance has its own SQLite DB, admin token, org structure, and email-sender identity. They share nothing — `DOMAIN` is single-value in Vaultwarden and drives email links + WebAuthn challenges + admin CSRF, so multi-route on one container would break passkeys/email-reset for the secondary domain.

## Architecture

- **Image:** `vaultwarden/server:latest` (Rust, ~50MB RAM each)
- **DB:** SQLite at `/data/db.sqlite3` inside container
- **TLS:** Cloudflare edge → CF tunnel → Traefik `web` entrypoint (HTTP origin)
- **Mail:** `claude@jeffemmett.com` via Mailcow on host (`mail.rmail.online:587` STARTTLS)
- **Admin gate:** Cloudflare Access on `/admin*` route (configured in CF dashboard, not Traefik)

## Deploy on Netcup

Live deploy lives at `/opt/apps/vaultwarden/`. To update from this repo:

```bash
ssh netcup-full
sudo rsync -av --delete /tmp/dev-ops/netcup/vaultwarden/docker-compose.yml /opt/apps/vaultwarden/
cd /opt/apps/vaultwarden
docker compose pull
docker compose up -d
docker compose logs -f vaultwarden
```

`/opt/apps/vaultwarden/.env` is host-local (mode 600, deploy user) and never committed.

## Generating admin tokens

```bash
# Run on WSL2 / dev machine
python3 -c '
import secrets, os
from argon2 import PasswordHasher
from argon2.low_level import Type
ph = PasswordHasher(time_cost=2, memory_cost=19456, parallelism=1, hash_len=32, salt_len=16, type=Type.ID)
old = os.umask(0o077)
p = secrets.token_urlsafe(32)
path = os.path.expanduser("~/.secrets/private/vw_admin_passphrase.txt")
with open(path, "w") as f: f.write(p + "\n")
os.chmod(path, 0o600); os.umask(old)
print("Plaintext:", path, "(mode 600)")
print("Hash:", ph.hash(p))
'
```

OWASP preset: `m=19456 KiB, t=2, p=1` — matches `vaultwarden hash --preset=owasp` (which requires a TTY and won't run inside CI/Bash tooling).

Plaintext → KeePass (then `shred -u` the file). Hash → Infisical project `vaultwarden` as `VW_ADMIN_TOKEN` (or directly into `/opt/apps/vaultwarden/.env`).

## First-run admin setup

1. Visit `https://passwords.jeffemmett.com/admin`, paste plaintext admin passphrase
2. Settings → **General** — verify domain, signups disabled
3. Settings → **SMTP** — send a test mail to confirm Mailcow path
4. Users → **Invite** — invite the first owner account
5. Owner accepts via email link, logs in, creates an Organization (the "team")
6. Owner adds members to the Org, creates Collections, shares creds

## Operational

### Backup

SQLite + attachments + RSA keys all live in the volume. Add to existing backup-system:

```bash
docker exec vaultwarden sqlite3 /data/db.sqlite3 ".backup /data/db-backup.sqlite3"
docker run --rm -v vaultwarden-data:/src -v /opt/backups:/dst alpine \
  tar czf /dst/vaultwarden-$(date +%F).tgz -C /src .
```

Wire into the existing restic→R2→Hetzner flow at `/opt/backup-system/`.

### Updates

```bash
cd /opt/apps/vaultwarden
docker compose pull
docker compose up -d
```

Vaultwarden is feature-stable; pin to a specific tag (`vaultwarden/server:1.36.0`) once chosen if you want zero-surprise updates.

### Monitoring

Add an HTTP push monitor in Uptime Kuma:
- `https://passwords.jeffemmett.com/alive` — returns 200 when up

Wire to the existing "Mailcow Email Alerts" notification.

### Migrating to Postgres later

If user count crosses ~100 active and write contention shows up:

1. Stop the instance
2. Run Vaultwarden's `sqlite-to-postgres.py` migration (in their repo `tools/`)
3. Add a dedicated `vaultwarden-db` Postgres container to compose
4. Switch `DATABASE_URL` env var
5. `docker compose up -d`

## Adding the commons-hub instance

When `passwords.commons-hub.io` DNS is live:

1. Uncomment the `vaultwarden-ch` service block in `docker-compose.yml`
2. Uncomment `vaultwarden-ch-data` under `volumes:`
3. Generate a second admin token (same script, different output filename)
4. Populate `VW_CH_ADMIN_TOKEN` + `VW_CH_SMTP_PASSWORD` in `/opt/apps/vaultwarden/.env`
5. Add a CF Access app for `passwords.commons-hub.io/admin*`
6. `docker compose up -d`

## Client setup

For end users — point Bitwarden official clients at the self-hosted server:

| Client | Setting |
|---|---|
| Browser ext | Settings → "Self-hosted environment" → Server URL: `https://passwords.jeffemmett.com` |
| iOS/Android | Login screen → settings cog → same server URL |
| Desktop app | File → Settings → Server URL |
| CLI (`bw`) | `bw config server https://passwords.jeffemmett.com` |

The self-hosted URL is per-device. Once set, login flow is identical to Bitwarden cloud.

## What this replaces

| Tool | Replaced? |
|---|---|
| Google Workspace password mgr | ✓ (for shared team passwords) |
| passwd.team add-on | ✓ (and doesn't require GSuite) |
| 1Password Teams | ✓ (basic feature parity) |
| KeePass for personal | ✗ — KeePass stays for solo/offline backup |
