#!/bin/bash
# infisical-ops.sh — Operational secrets helper for Claude Code
# Fetches secrets from Infisical claude-ops project and either:
#   - Lists secret NAMES only (no values shown)
#   - Runs a command with secrets injected as env vars (pass-through)
#   - Gets a single secret value (for piping, not display)
#
# Usage:
#   infisical-ops list [folder]           # List secret names in folder
#   infisical-ops run [folder] -- cmd     # Run cmd with secrets injected
#   infisical-ops get KEY [folder]        # Get single secret (for piping)
#   infisical-ops folders                 # List all folders
#
set -euo pipefail

INFISICAL_URL="${INFISICAL_API_URL:-https://secrets.jeffemmett.com}"
PROJECT_ID="5b64ec1b-5b67-4b48-8808-c2465c0be41a"

# Bootstrap credentials (the only secrets stored as files)
if [ -f "$HOME/.secrets/infisical_admin_client_id" ]; then
  CLIENT_ID=$(tr -d '\r\n' < "$HOME/.secrets/infisical_admin_client_id")
  CLIENT_SECRET=$(tr -d '\r\n' < "$HOME/.secrets/infisical_admin_client_secret")
elif [ -f "/opt/infisical/claude-ops.env" ]; then
  source /opt/infisical/claude-ops.env
  CLIENT_ID="$INFISICAL_CLIENT_ID"
  CLIENT_SECRET="$INFISICAL_CLIENT_SECRET"
else
  echo "ERROR: No Infisical credentials found" >&2
  exit 1
fi

# Cloudflare Access credentials (for external access through CF tunnel)
CF_ACCESS_HEADERS=""
if [ -f "$HOME/.secrets/cf_access_infisical_client_id" ]; then
  CF_ACCESS_ID=$(tr -d '\r\n' < "$HOME/.secrets/cf_access_infisical_client_id")
  CF_ACCESS_SECRET=$(tr -d '\r\n' < "$HOME/.secrets/cf_access_infisical_client_secret")
  CF_ACCESS_HEADERS="-H CF-Access-Client-Id:$CF_ACCESS_ID -H CF-Access-Client-Secret:$CF_ACCESS_SECRET"
fi

# Authenticate
get_token() {
  curl -sf --connect-timeout 10 --max-time 30 $CF_ACCESS_HEADERS \
    -X POST "$INFISICAL_URL/api/v1/auth/universal-auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"clientId\": \"$CLIENT_ID\", \"clientSecret\": \"$CLIENT_SECRET\"}" | jq -r '.accessToken'
}

CMD="${1:-help}"
shift || true

case "$CMD" in
  list)
    FOLDER="${1:-/}"
    TOKEN=$(get_token)
    echo "Secrets in $FOLDER:"
    curl -sf $CF_ACCESS_HEADERS "$INFISICAL_URL/api/v3/secrets/raw?workspaceId=$PROJECT_ID&environment=prod&secretPath=$FOLDER" \
      -H "Authorization: Bearer $TOKEN" | jq -r '.secrets[].secretKey' | sort
    ;;

  list-all)
    TOKEN=$(get_token)
    curl -sf $CF_ACCESS_HEADERS "$INFISICAL_URL/api/v3/secrets/raw?workspaceId=$PROJECT_ID&environment=prod&secretPath=/&recursive=true" \
      -H "Authorization: Bearer $TOKEN" | jq -r '.secrets[] | "\(.secretPath)/\(.secretKey)"' | sort
    ;;

  folders)
    TOKEN=$(get_token)
    curl -sf $CF_ACCESS_HEADERS "$INFISICAL_URL/api/v1/folders?workspaceId=$PROJECT_ID&environment=prod&path=/" \
      -H "Authorization: Bearer $TOKEN" | jq -r '.folders[].name' | sort
    ;;

  get)
    # Gets a single secret value — intended for piping to commands, not display
    KEY="${1:?Usage: infisical-ops get KEY [folder]}"
    FOLDER="${2:-/}"
    TOKEN=$(get_token)
    curl -sf $CF_ACCESS_HEADERS "$INFISICAL_URL/api/v3/secrets/raw/$KEY?workspaceId=$PROJECT_ID&environment=prod&secretPath=$FOLDER" \
      -H "Authorization: Bearer $TOKEN" | jq -r '.secret.secretValue'
    ;;

  run)
    # Run a command with secrets injected from a folder
    FOLDER="/"
    RECURSIVE="false"
    while [[ $# -gt 0 && "$1" != "--" ]]; do
      case "$1" in
        --path) FOLDER="$2"; shift 2 ;;
        --recursive) RECURSIVE="true"; shift ;;
        *) FOLDER="$1"; shift ;;
      esac
    done
    shift # skip --

    TOKEN=$(get_token)
    QUERY="workspaceId=$PROJECT_ID&environment=prod&secretPath=$FOLDER"
    [ "$RECURSIVE" = "true" ] && QUERY="$QUERY&recursive=true"

    # Fetch secrets and export as env vars
    EXPORTS=$(curl -sf $CF_ACCESS_HEADERS "$INFISICAL_URL/api/v3/secrets/raw?$QUERY" \
      -H "Authorization: Bearer $TOKEN" | \
      jq -r '.secrets[] | "export \(.secretKey)='"'"'\(.secretValue | gsub("'"'"'"; "'"'"'\\'"'"''"'"'"))'"'"'"' )

    eval "$EXPORTS"
    exec "$@"
    ;;

  set)
    # Set/create a secret: infisical-ops set KEY VALUE [folder]
    KEY="${1:?Usage: infisical-ops set KEY VALUE [folder]}"
    VALUE="${2:?Usage: infisical-ops set KEY VALUE [folder]}"
    FOLDER="${3:-/}"
    TOKEN=$(get_token)

    # Create folder if needed (ignore errors for existing folders)
    if [ "$FOLDER" != "/" ]; then
      PARENT_PATH=$(dirname "$FOLDER")
      [ "$PARENT_PATH" = "." ] && PARENT_PATH="/"
      FOLDER_NAME=$(basename "$FOLDER")
      curl -sf $CF_ACCESS_HEADERS -X POST "$INFISICAL_URL/api/v1/folders" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
        -d "{\"workspaceId\": \"$PROJECT_ID\", \"environment\": \"prod\", \"name\": \"$FOLDER_NAME\", \"path\": \"$PARENT_PATH\"}" >/dev/null 2>&1 || true
    fi

    # Try to create the secret
    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" $CF_ACCESS_HEADERS \
      -X POST "$INFISICAL_URL/api/v3/secrets/raw/$KEY" \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      -d "{\"workspaceId\": \"$PROJECT_ID\", \"environment\": \"prod\", \"secretPath\": \"$FOLDER\", \"secretValue\": $(echo -n "$VALUE" | jq -Rs .)}" 2>/dev/null)

    if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "409" ]; then
      # Secret exists, update it
      curl -sf $CF_ACCESS_HEADERS \
        -X PATCH "$INFISICAL_URL/api/v3/secrets/raw/$KEY" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
        -d "{\"workspaceId\": \"$PROJECT_ID\", \"environment\": \"prod\", \"secretPath\": \"$FOLDER\", \"secretValue\": $(echo -n "$VALUE" | jq -Rs .)}" >/dev/null
      echo "Updated: $KEY in $FOLDER"
    else
      echo "Created: $KEY in $FOLDER"
    fi
    ;;

  mkdir)
    # Create a folder: infisical-ops mkdir /path/to/folder
    FOLDER="${1:?Usage: infisical-ops mkdir /path/to/folder}"
    TOKEN=$(get_token)
    PARENT_PATH=$(dirname "$FOLDER")
    [ "$PARENT_PATH" = "." ] && PARENT_PATH="/"
    FOLDER_NAME=$(basename "$FOLDER")
    curl -sf $CF_ACCESS_HEADERS -X POST "$INFISICAL_URL/api/v1/folders" \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      -d "{\"workspaceId\": \"$PROJECT_ID\", \"environment\": \"prod\", \"name\": \"$FOLDER_NAME\", \"path\": \"$PARENT_PATH\"}" | jq -r '.folder.name // "created"'
    echo "Created folder: $FOLDER"
    ;;

  help|--help|-h)
    echo "infisical-ops — Operational secrets for Claude Code"
    echo ""
    echo "Usage:"
    echo "  infisical-ops list [folder]              List secret NAMES (no values)"
    echo "  infisical-ops list-all                   List all secrets across all folders"
    echo "  infisical-ops folders                    List available folders"
    echo "  infisical-ops get KEY [folder]           Get single secret value (for piping)"
    echo "  infisical-ops set KEY VALUE [folder]     Create/update a secret"
    echo "  infisical-ops mkdir /folder              Create a folder"
    echo "  infisical-ops run [--path folder] -- cmd Run cmd with secrets as env vars"
    echo ""
    echo "Folders: cloudflare, erpnext, monitoring, n8n, ecommerce, infra, git, mail, ai, vault-migration"
    ;;

  *)
    echo "Unknown command: $CMD" >&2
    echo "Run 'infisical-ops help' for usage" >&2
    exit 1
    ;;
esac
