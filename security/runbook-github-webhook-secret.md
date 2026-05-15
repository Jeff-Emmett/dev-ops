# Runbook: rotate the GitHub webhook HMAC secret

**Cadence**: 180 days. Inventory entry: `github-webhook-secret`.

The HMAC secret GitHub signs push-webhook deliveries with, verified by
`/opt/deploy-webhook` (`GITHUB_WEBHOOK_SECRET`, a Docker secret from
`/root/.secrets/github_webhook_secret`). Sibling of the Gitea webhook
secret — but that one is `mode: auto` (`rotate-gitea-webhook.sh` updates
~100 Gitea hooks via API in one pass). GitHub has no bulk-update API for
webhook secrets, so this stays manual: each repo's webhook is configured
individually and `gh` must be authed per repo.

## Pre-flight
```bash
# Which repos point a webhook at deploy.jeffemmett.com?
gh api user/repos --paginate --jq '.[].full_name' \
  | while read r; do
      gh api "repos/$r/hooks" --jq '.[] | select(.config.url|test("deploy.jeffemmett.com")) | "'$r'"' 2>/dev/null
    done | sort -u | tee /tmp/gh-webhook-repos.txt
```

## Steps
1. New secret: `NEW=$(openssl rand -hex 32)`
2. Update the server side (deploy-webhook reads it as a Docker secret):
   ```bash
   ssh netcup-full 'cp /root/.secrets/github_webhook_secret /root/.secrets/github_webhook_secret.bak.$(date -u +%Y%m%d-%H%M%S)'
   printf '%s' "$NEW" | ssh netcup-full 'cat > /root/.secrets/github_webhook_secret && chmod 600 /root/.secrets/github_webhook_secret'
   ssh netcup-full 'docker restart deploy-webhook'
   ```
3. Update each repo's webhook (from the pre-flight list):
   ```bash
   while read r; do
     hid=$(gh api "repos/$r/hooks" --jq '.[] | select(.config.url|test("deploy.jeffemmett.com")) | .id')
     gh api -X PATCH "repos/$r/hooks/$hid" -f "config[secret]=$NEW" >/dev/null \
       && echo "ok $r" || echo "FAIL $r"
   done < /tmp/gh-webhook-repos.txt
   ```
4. Smoke test: push a trivial commit to one repo → GitHub redelivers →
   deploy-webhook accepts (HTTP 200, signature verified):
   ```bash
   ssh netcup 'docker logs --since 60s deploy-webhook 2>&1 | grep -iE "signature|github|401|200"'
   ```
   A `signature mismatch` / 401 means a repo (or the server file) still
   has the old secret.
5. `./security/mark-rotated.sh github-webhook-secret` + commit.

## If something goes wrong
- **deploy-webhook 401s every GitHub delivery** → server file updated
  but a repo wasn't, OR vice-versa. The server side is one file; if it's
  right, re-run step 3 for the failing repo (its delivery log in GitHub
  → repo → Settings → Webhooks → Recent Deliveries names it).
- **gh PATCH "config[secret]" not taking** → GitHub returns the hook
  without the secret (write-only field) so you can't read-back-verify;
  the real verification is step 4's live delivery.

## Cross-references
`rotate-gitea-webhook.sh` (the automated sibling — Gitea side),
`runbook-github-pat.md` (the gh auth this depends on),
`gitea-webhook-secret` inventory entry.
