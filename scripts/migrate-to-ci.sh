#!/usr/bin/env bash
# migrate-to-ci.sh — Copy CI/CD workflow template to a repo and configure it
#
# Usage:
#   ./migrate-to-ci.sh <repo-path> <template> <app-name> <deploy-path> <health-url>
#
# Example:
#   ./migrate-to-ci.sh ~/Github/my-app node-app my-app /opt/apps/my-app https://my-app.jeffemmett.com/
#
# Templates: node-app, python-app, static-site
# After running: commit + push, then disable the Gitea webhook for the repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../ci-templates"

if [ $# -lt 5 ]; then
  echo "Usage: $0 <repo-path> <template> <app-name> <deploy-path> <health-url>"
  echo ""
  echo "Templates available:"
  ls "$TEMPLATE_DIR"/*.yml 2>/dev/null | xargs -I{} basename {} .yml
  exit 1
fi

REPO_PATH="$1"
TEMPLATE="$2"
APP_NAME="$3"
DEPLOY_PATH="$4"
HEALTH_URL="$5"

TEMPLATE_FILE="$TEMPLATE_DIR/${TEMPLATE}.yml"

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: Template '$TEMPLATE' not found at $TEMPLATE_FILE"
  exit 1
fi

if [ ! -d "$REPO_PATH" ]; then
  echo "Error: Repo path '$REPO_PATH' not found"
  exit 1
fi

# Create workflow directory
mkdir -p "$REPO_PATH/.gitea/workflows"

# Copy and substitute template
sed \
  -e "s|__APP_NAME__|$APP_NAME|g" \
  -e "s|__DEPLOY_PATH__|$DEPLOY_PATH|g" \
  -e "s|__HEALTH_URL__|$HEALTH_URL|g" \
  "$TEMPLATE_FILE" > "$REPO_PATH/.gitea/workflows/ci.yml"

echo "Created: $REPO_PATH/.gitea/workflows/ci.yml"
echo ""
echo "Next steps:"
echo "  1. cd $REPO_PATH"
echo "  2. Review .gitea/workflows/ci.yml"
echo "  3. git add .gitea/workflows/ci.yml && git commit -m 'Add CI/CD pipeline'"
echo "  4. git push origin dev"
echo "  5. Verify CI runs pass in Gitea Actions"
echo "  6. Enable Actions: curl -X PATCH https://gitea.jeffemmett.com/api/v1/repos/jeffemmett/$APP_NAME -H 'Authorization: token <PAT>' -H 'Content-Type: application/json' -d '{\"has_actions\": true}'"
echo "  7. Seed registry: ssh netcup-full 'docker tag <current-image> gitea.jeffemmett.com/jeffemmett/$APP_NAME:latest && docker push ...'"
echo "  8. Update server-side docker-compose.yml: image: gitea.jeffemmett.com/jeffemmett/$APP_NAME:\${IMAGE_TAG:-latest}"
echo "  9. Disable Gitea webhook for the repo"
