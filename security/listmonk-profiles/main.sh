#!/usr/bin/env bash
# Listmonk MAIN instance — sourced by ../rotate-listmonk-postgres.sh
INVENTORY_NAME="listmonk-main-postgres"
INST_DIR="/opt/apps/listmonk"
DB_CONTAINER="listmonk-db"
APP_CONTAINER="listmonk"
PG_USER="listmonk"
PG_DB="listmonk"
ENV_VAR="LISTMONK_DB_PASSWORD"
SSH_TARGET="${SSH_TARGET:-netcup-full}"
