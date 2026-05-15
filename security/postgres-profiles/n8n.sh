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
