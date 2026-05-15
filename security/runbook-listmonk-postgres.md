# Runbook: rotate Listmonk Postgres password (split DB/app config)

**Cadence**: 180 days. Inventory entries: `listmonk-main-postgres`,
`xhiva-listmonk-postgres`.

> **Why this is a runbook, not `mode: auto`.** Listmonk stores the DB
> password in **two independent places** that must hold the same value:
> - `.env` → `LISTMONK_DB_PASSWORD` → interpolated into the postgres
>   container's `POSTGRES_PASSWORD` (DB side)
> - `config.toml` → `[db] password = "…"` (bind-mounted read-only into
>   the app at `/listmonk/config.toml`) — **the APP side**
>
> The generic `rotate-postgres-password.sh` only touches the `.env`
> side. Running it here on 2026-05-15 changed the DB password, left the
> app's `config.toml` stale, and flooded `pq: password authentication
> failed` until reverted — while the DB-only smoke test falsely passed.
> See memory `postgres_rotation_consumer_verification`. Rotate **both
> files in lockstep**.

This runbook covers two instances (run the steps per instance):

| Instance | env (DB side) | config.toml (app side) | DB container | app container |
|---|---|---|---|---|
| main | `/opt/apps/listmonk/.env` | `/opt/apps/listmonk/config.toml` | `listmonk-db` | `listmonk` |
| xhiva | `/opt/websites/xhivart-mirror/listmonk/.env` | `/opt/websites/xhivart-mirror/listmonk/config.toml` | `xhiva-listmonk-db` | `xhiva-listmonk` |

(The 4 tenant instances — p2p / worldplay / crypto-commons / commons-hub
— use Docker-secret passwords, not env, and aren't inventoried yet.
Different procedure; out of scope here.)

## Pre-flight (per instance — example uses `main`; substitute for xhiva)

```bash
ssh netcup-full
INST_DIR=/opt/apps/listmonk            # xhiva: /opt/websites/xhivart-mirror/listmonk
DB_C=listmonk-db                       # xhiva: xhiva-listmonk-db
APP_C=listmonk                         # xhiva: xhiva-listmonk

# Baseline: app currently healthy?
docker logs --tail 5 "$APP_C" 2>&1 | grep -iE "http server started|password authentication"

# Capture OLD pw from config.toml (the app side is source of truth here)
docker exec "$APP_C" sh -c 'grep "^password" /listmonk/config.toml'
```

## Steps (per instance)

### 1. Generate a new password

```bash
NEW=$(openssl rand -hex 24)   # 48 hex chars; no shell-special chars
echo "$NEW"   # note it; you'll paste into two files
```

### 2. Back up both files

```bash
TS=$(date -u +%Y%m%d-%H%M%S)
cp "$INST_DIR/.env"          "$INST_DIR/.env.bak-pre-rotate-$TS"
cp "$INST_DIR/config.toml"   "$INST_DIR/config.toml.bak-pre-rotate-$TS"
```

### 3. Change the password IN the database (connect with OLD)

```bash
OLD=$(grep "^LISTMONK_DB_PASSWORD=" "$INST_DIR/.env" | sed 's/^[^=]*=//; s/^"//; s/"$//')
docker exec -e PGPASSWORD="$OLD" "$DB_C" \
  psql -U listmonk -d listmonk -c "ALTER USER listmonk WITH PASSWORD '$NEW';"
# Expect: ALTER ROLE
```

### 4. Update BOTH files to the new value

```bash
# DB side (.env)
sed -i "s|^LISTMONK_DB_PASSWORD=.*|LISTMONK_DB_PASSWORD=$NEW|" "$INST_DIR/.env"

# App side (config.toml [db] password). The line looks like:
#   password = "..."   (note the quotes and spaces vary — match loosely)
sed -i -E "s|^password[[:space:]]*=.*|password = \"$NEW\"|" "$INST_DIR/config.toml"

# Verify both now show the new value:
grep "^LISTMONK_DB_PASSWORD=" "$INST_DIR/.env"
grep "^password" "$INST_DIR/config.toml"
```

### 5. Recreate both containers

```bash
cd "$INST_DIR" && docker compose up -d --force-recreate
sleep 8
```

### 6. Verify the CONSUMER reconnected (the step the generic script lacked)

```bash
docker logs --since 40s "$APP_C" 2>&1 | grep -iE \
  "password authentication failed|error connecting to DB|error fetching campaigns|http server started"
```

- ✅ Success: `http server started on [::]:9000`, **no** auth-failure lines.
- ❌ Failure: any `password authentication failed` → go to rollback.

### 7. Record (only after step 6 is clean)

```bash
cd ~/Github/dev-ops
./security/mark-rotated.sh listmonk-main-postgres   # or xhiva-listmonk-postgres
git add security/secrets-inventory.yaml
git commit -m "security: rotate listmonk-<inst>-postgres (mark inventory)"
```

## Rollback

If step 6 shows auth failures:

```bash
# Re-set the DB password back to OLD (connect with the NEW you just set)
docker exec -e PGPASSWORD="$NEW" "$DB_C" \
  psql -U listmonk -d listmonk -c "ALTER USER listmonk WITH PASSWORD '$OLD';"
# Restore both files
cp "$INST_DIR/.env.bak-pre-rotate-$TS"        "$INST_DIR/.env"
cp "$INST_DIR/config.toml.bak-pre-rotate-$TS" "$INST_DIR/config.toml"
cd "$INST_DIR" && docker compose up -d --force-recreate
sleep 8
docker logs --tail 5 "$APP_C" 2>&1 | grep -i "http server started"
```

This is exactly the recovery used on 2026-05-15 — it restores cleanly.

## If something goes wrong

- **`config.toml` is mounted `:ro`** — that's fine, you edit the host
  file (`$INST_DIR/config.toml`); the read-only flag only applies inside
  the container. The recreate re-mounts the updated host file.
- **`sed` didn't match the `password` line** — listmonk's config.toml
  may use `password="x"` (no spaces) or `password = 'x'`. Inspect with
  `grep -n password "$INST_DIR/config.toml"` and adjust the sed.
- **Other consumers** — listmonk's DB is single-app; nothing else
  connects. No fan-out to chase.

## Cross-references

- Inventory: `listmonk-main-postgres`, `xhiva-listmonk-postgres`
- Memory: `postgres_rotation_consumer_verification` (the incident)
- The generic `rotate-postgres-password.sh` now has a
  `CONSUMER_CONTAINER` guard so a listmonk-class split-config service
  fails loudly instead of silently — but listmonk itself stays manual
  because the app-side file (`config.toml`) needs editing too, which the
  generic .env-only rotator can't do.
