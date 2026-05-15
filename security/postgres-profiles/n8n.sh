#!/usr/bin/env bash
# Postgres rotation profile for n8n (workflow engine).
# Sourced by ../rotate-postgres-password.sh.

INVENTORY_NAME="n8n-postgres"
PG_CONTAINER="n8n-postgres"
PG_DB="n8n"
PG_USER="n8n"
ENV_PATH="/opt/n8n/.env"
ENV_VAR="POSTGRES_PASSWORD"
SSH_TARGET="${SSH_TARGET:-netcup-full}"
RESTART_CMD="cd /opt/n8n && docker compose up -d"

# Consumer-side verification (added after the 2026-05-15 listmonk incident).
# n8n is structurally SAFE for the generic rotator: both the app
# (DB_POSTGRESDB_PASSWORD) and the postgres container (POSTGRES_PASSWORD)
# interpolate the SAME ${POSTGRES_PASSWORD} from .env, so `docker compose
# up -d` recreates both in sync. CONSUMER_CONTAINER lets the script
# confirm the app actually reconnected (belt-and-suspenders).
CONSUMER_CONTAINER="n8n"
# default CONSUMER_AUTH_ERROR_RE covers the common signatures; n8n logs
# "password authentication failed" on a bad DB credential.
