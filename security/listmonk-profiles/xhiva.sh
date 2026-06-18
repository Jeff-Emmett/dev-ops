#!/usr/bin/env bash
# Listmonk XHIVA mirror instance — sourced by ../rotate-listmonk-postgres.sh
INVENTORY_NAME="xhiva-listmonk-postgres"
INST_DIR="/opt/websites/xhivart-mirror/listmonk"
DB_CONTAINER="xhiva-listmonk-db"
APP_CONTAINER="xhiva-listmonk"
PG_USER="listmonk"
PG_DB="listmonk"
ENV_VAR="LISTMONK_DB_PASSWORD"
SSH_TARGET="${SSH_TARGET:-netcup-full}"
