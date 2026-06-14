#!/usr/bin/env bash
# Deploy the LiteLLM proxy config from this repo to the live mount on Netcup.
#
# Replaces the old undocumented "manual cp" step. Run ON Netcup:
#   ssh netcup-full 'bash /opt/dev-ops/netcup/litellm/deploy.sh'
#
# What it does (in order, fail-fast):
#   1. git pull the dev-ops checkout so the repo config is current
#   2. validate the repo config as YAML
#   3. back up the live config (timestamped)
#   4. copy repo config -> live mount ONLY if it differs
#   5. restart the litellm container so changes load
#
# Safe to re-run: a no-op if the live config already matches the repo.
set -euo pipefail

REPO_DIR="/opt/dev-ops"
SRC="${REPO_DIR}/netcup/litellm/config.yaml"
DEST="/opt/apps/litellm/config.yaml"
COMPOSE_DIR="/opt/apps/litellm"
CONTAINER="litellm"

echo "==> Pulling ${REPO_DIR} (dev)"
git -C "${REPO_DIR}" pull --ff-only origin dev

echo "==> Validating ${SRC} as YAML"
python3 -c "import yaml,sys; yaml.safe_load(open('${SRC}')); print('    YAML OK')"

if [ ! -f "${DEST}" ]; then
  echo "!!  ${DEST} missing — refusing to create blind. Inspect manually." >&2
  exit 1
fi

if diff -q "${DEST}" "${SRC}" >/dev/null; then
  echo "==> Live config already matches repo — nothing to deploy."
  exit 0
fi

TS="$(date +%Y%m%d-%H%M%S)"
echo "==> Backing up live config -> ${DEST}.bak-${TS}"
cp -a "${DEST}" "${DEST}.bak-${TS}"

echo "==> Changes about to deploy (live <- repo):"
diff "${DEST}" "${SRC}" || true

echo "==> Copying repo config into place"
cp "${SRC}" "${DEST}"

echo "==> Restarting ${CONTAINER}"
( cd "${COMPOSE_DIR}" && docker compose restart "${CONTAINER}" )

echo "==> Done. Container status:"
docker ps --filter "name=${CONTAINER}" --format "    {{.Names}} {{.Status}}"
