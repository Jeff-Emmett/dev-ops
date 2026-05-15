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
```

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
