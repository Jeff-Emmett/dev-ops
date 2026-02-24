#!/bin/bash
# Create an Infisical project + machine identity for a service
# Usage: ./create-project.sh <project-slug> [org-slug]
#
# Prerequisites:
#   - INFISICAL_TOKEN env var set (org admin token or machine identity with project-create perms)
#   - INFISICAL_URL env var or defaults to https://secrets.jeffemmett.com
#
# What this does:
#   1. Creates a new Infisical project
#   2. Creates a machine identity for the project
#   3. Adds universal auth to the identity
#   4. Grants the identity viewer access to the project
#   5. Outputs the CLIENT_ID and CLIENT_SECRET for docker-compose .env

set -euo pipefail

SLUG="${1:?Usage: $0 <project-slug> [org-slug]}"
ORG_SLUG="${2:-jeff}"
INFISICAL_URL="${INFISICAL_URL:-https://secrets.jeffemmett.com}"

if [ -z "${INFISICAL_TOKEN:-}" ]; then
  echo "ERROR: INFISICAL_TOKEN must be set (org admin access token)"
  exit 1
fi

API="${INFISICAL_URL}/api"
AUTH="Authorization: Bearer ${INFISICAL_TOKEN}"

echo "=== Creating Infisical project: ${SLUG} ==="

# 1. Create project
echo "[1/5] Creating project..."
PROJECT=$(curl -sf -X POST "${API}/v2/workspace" \
  -H "${AUTH}" \
  -H "Content-Type: application/json" \
  -d "{\"projectName\":\"${SLUG}\",\"slug\":\"${SLUG}\"}")

PROJECT_ID=$(echo "$PROJECT" | jq -r '.workspace.id // .project.id // empty')
if [ -z "$PROJECT_ID" ]; then
  echo "ERROR: Failed to create project. Response:"
  echo "$PROJECT" | jq .
  exit 1
fi
echo "  Project ID: ${PROJECT_ID}"

# 2. Create machine identity
echo "[2/5] Creating machine identity..."
IDENTITY=$(curl -sf -X POST "${API}/v1/identities" \
  -H "${AUTH}" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${SLUG}-deploy\",\"role\":\"member\",\"organizationId\":\"$(echo "$PROJECT" | jq -r '.workspace.orgId // .project.orgId')\"}")

IDENTITY_ID=$(echo "$IDENTITY" | jq -r '.identity.id // empty')
if [ -z "$IDENTITY_ID" ]; then
  echo "ERROR: Failed to create identity. Response:"
  echo "$IDENTITY" | jq .
  exit 1
fi
echo "  Identity ID: ${IDENTITY_ID}"

# 3. Add universal auth
echo "[3/5] Adding universal auth..."
UA=$(curl -sf -X POST "${API}/v1/auth/universal-auth/identities/${IDENTITY_ID}" \
  -H "${AUTH}" \
  -H "Content-Type: application/json" \
  -d '{"accessTokenTTL":0,"accessTokenMaxTTL":0,"accessTokenNumUsesLimit":0}')

# 4. Create client secret
echo "[4/5] Creating client credentials..."
CLIENT_SECRET_RESP=$(curl -sf -X POST "${API}/v1/auth/universal-auth/identities/${IDENTITY_ID}/client-secrets" \
  -H "${AUTH}" \
  -H "Content-Type: application/json" \
  -d '{"description":"deploy","numUsesLimit":0,"ttl":0}')

CLIENT_ID=$(echo "$UA" | jq -r '.identityUniversalAuth.clientId // empty')
CLIENT_SECRET=$(echo "$CLIENT_SECRET_RESP" | jq -r '.clientSecret // empty')

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "ERROR: Failed to get credentials"
  echo "UA response:" && echo "$UA" | jq .
  echo "Secret response:" && echo "$CLIENT_SECRET_RESP" | jq .
  exit 1
fi

# 5. Grant identity access to project (viewer role)
echo "[5/5] Granting project access..."
curl -sf -X POST "${API}/v2/workspace/${PROJECT_ID}/identity-memberships/${IDENTITY_ID}" \
  -H "${AUTH}" \
  -H "Content-Type: application/json" \
  -d '{"role":"viewer"}' > /dev/null

echo ""
echo "=== Done! ==="
echo ""
echo "Add these to your .env file:"
echo "  INFISICAL_CLIENT_ID=${CLIENT_ID}"
echo "  INFISICAL_CLIENT_SECRET=${CLIENT_SECRET}"
echo "  INFISICAL_PROJECT_SLUG=${SLUG}"
echo ""
echo "Next steps:"
echo "  1. Push secrets: ./migrate-env.sh <path-to-.env> ${SLUG}"
echo "  2. Add entrypoint to Dockerfile or docker-compose.yml"
echo "  3. Deploy and verify: docker logs <container> | grep infisical"
