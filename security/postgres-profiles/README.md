# Postgres rotation profiles

`rotate-postgres-password.sh` is generic — each service-specific knob lives
in a profile here. Add a new profile to add a new service.

## Profile template

```bash
#!/usr/bin/env bash
# Per-service Postgres rotation knobs. Sourced by ../rotate-postgres-password.sh.

INVENTORY_NAME="<inventory-entry-name>"   # e.g. n8n-postgres
PG_CONTAINER="<docker-container-name>"    # e.g. n8n-postgres
PG_DB="<database-name>"                   # e.g. n8n
PG_USER="<role-name>"                     # e.g. n8n
ENV_PATH="<absolute-path-to-.env>"        # e.g. /opt/n8n/.env
ENV_VAR="<env-var-to-replace>"            # e.g. POSTGRES_PASSWORD
SSH_TARGET="${SSH_TARGET:-netcup-full}"   # override allowed
RESTART_CMD="<shell command to restart consumer>"
# RESTART_CMD example: "cd /opt/n8n && docker compose up -d"

# STRONGLY RECOMMENDED — consumer-side verification:
CONSUMER_CONTAINER="<app-container-name>"   # e.g. n8n
# Optional: override the auth-failure regex scanned in the consumer's
# post-restart logs (default covers the common signatures):
# CONSUMER_AUTH_ERROR_RE="password authentication failed|FATAL.*password"
```

## Why CONSUMER_CONTAINER matters (2026-05-15 listmonk incident)

A DB-only smoke test (`psql SELECT 1` with the new password) is a
**false pass** for any service whose app reads its DB password from a
config *separate* from the env var being rotated. listmonk is exactly
this: `LISTMONK_DB_PASSWORD` feeds only the postgres container's
`POSTGRES_PASSWORD`; the listmonk app authenticates from its own
`config.toml`. Rotating naively changed the DB side, the app kept the
old credential, and it flooded `password authentication failed` until
reverted — yet the DB smoke test had reported success.

**Before adding a profile, verify the app and the postgres container
derive the DB password from the SAME source.** Grep the compose file:
if the app service's DB-password env and the postgres service's
`POSTGRES_PASSWORD` both interpolate the *same* `${VAR}`, it's safe
(n8n is). If they're independent, the generic rotator is UNSAFE for
that service — use a manual runbook that rotates both sides in lockstep.

With `CONSUMER_CONTAINER` set, the script scans that container's logs
after restart and aborts (with revert guidance) if auth errors appear —
turning the silent listmonk-class failure into a hard, actionable stop.

## Usage

```bash
./security/rotate-postgres-password.sh --dry-run n8n
./security/rotate-postgres-password.sh n8n
```

## Why profiles instead of inventory fields

The inventory's `consumers.action` could in principle hold this metadata,
but it's deliberately loose — services with unusual rotation flows (multiple
DB hosts, special restart sequences) need full shell. Profiles bottle that
without polluting the inventory format.

## Adding a new profile

1. Copy an existing profile (`n8n.sh`).
2. Verify with `--dry-run` — the dry run logs every step.
3. Run for real once with the container up and the inventory entry's
   `last_rotated` clearly set. The script does the rest.
4. Update the matching `secrets-inventory.yaml` entry:
   - `rotation.mode: auto`
   - `rotation.script: rotate-postgres-password.sh <profile-name>`
