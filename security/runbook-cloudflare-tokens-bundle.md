# Runbook: rotate Cloudflare tokens bundle

**Cadence**: 180 days. Inventory entry: `cloudflare-tokens-bundle`.

Highest-blast-radius credential set on this stack. The bundle at
`/opt/secrets/cloudflare/.env` on Netcup holds **6 different CF tokens**
plus the PocketID API key. A bad rotation can take down DNS, the
Cloudflare tunnel (cutting *all* inbound traffic to Netcup), R2 backups,
and IDP automation.

The seven values:
| Var | Scope | Consumers |
|---|---|---|
| `CLOUDFLARE_ACCOUNT_ID` | identifier (not secret) | every script — leave as-is, this isn't rotated |
| `CLOUDFLARE_INFRA_TOKEN` | Account-wide infra (zone:edit, worker:edit) | provisioning scripts, dev-ops infra automation |
| `CLOUDFLARE_TUNNEL_TOKEN` | Zero Trust tunnel | `cloudflared` daemon on Netcup |
| `CLOUDFLARE_API_TOKEN` | Zone:read, Worker:read, R2:read/edit | most agents + backup-system R2 sync |
| `CLOUDFLARE_ANALYTICS_TOKEN` | Analytics read | dashboards |
| `CLOUDFLARE_IDP_MGMT_TOKEN` | Access app + policy management | TASK-low.7 work, future CF Access automation |
| `POCKETID_API_KEY` | PocketID IDP — separate provider, separate rotation | tracked under `pocketid-api-key` inventory entry |

**Rotate the 5 CF tokens, NOT POCKETID_API_KEY here** — that has its own
runbook. Bundle is mixed-provider for historical convenience.

## Pre-flight

- CF dashboard open: <https://dash.cloudflare.com/profile/api-tokens>
- Zero Trust dashboard for tunnel: <https://one.dash.cloudflare.com/>
- Current backup of the bundle in case rollback needed:
  ```bash
  ssh netcup-full 'cp /opt/secrets/cloudflare/.env /opt/secrets/cloudflare/.env.bak-pre-rotate-$(date -u +%Y%m%d-%H%M%S)'
  ```
- Confirm tunnel is currently healthy — you'll want a baseline to compare
  against post-rotation:
  ```bash
  curl -sI https://passwords.jeffemmett.com/ | head -2
  curl -sI https://status.jeffemmett.com/ | head -2
  ```

## Critical ordering rule

**Rotate `CLOUDFLARE_TUNNEL_TOKEN` LAST and SEPARATELY** from the other
API tokens. The tunnel token is what `cloudflared` uses to authenticate
its outbound connection to CF. If you mess up rotation, the tunnel
disconnects and every CF-tunnel-routed service becomes unreachable from
outside until you fix it.

For the API tokens (INFRA, API, ANALYTICS, IDP_MGMT), order doesn't
matter much — services that consume them are not on the critical-path
ingress.

## Steps — API tokens (INFRA, API, ANALYTICS, IDP_MGMT)

### 1. Create replacement tokens in the CF dashboard

For each of the four API tokens, in CF dashboard → API Tokens:

1. Click "Create Token".
2. Use the **template that matches the existing token's scope** — don't
   widen permissions. The four scopes:
   - `CLOUDFLARE_INFRA_TOKEN`: Zone:Edit, Worker:Edit, Account:Read,
     User:Read across **all** zones in this account.
   - `CLOUDFLARE_API_TOKEN`: Zone:Read, Worker:Read/Edit, R2:Read/Edit
     across **all** zones (used heavily; least-privilege candidate).
   - `CLOUDFLARE_ANALYTICS_TOKEN`: Analytics:Read across all zones.
   - `CLOUDFLARE_IDP_MGMT_TOKEN`: Account → Access: Apps and Policies:
     Edit + Access: Service Tokens: Edit.
3. Name each `<original-name>-rotated-YYYY-MM-DD`.
4. **Copy each value once** — not shown again. Drop into
   `~/.secrets/private/cloudflare-rotation-YYYY-MM-DD.txt` (mode 600),
   keyed by env-var name. Will be shredded at the end.

### 2. Update the bundle on Netcup

```bash
ssh netcup-full
cd /opt/secrets/cloudflare
cp .env .env.bak-pre-rotate-$(date -u +%Y%m%d-%H%M%S)

# Edit .env with $EDITOR; replace exactly these four lines:
#   CLOUDFLARE_INFRA_TOKEN=<new>
#   CLOUDFLARE_API_TOKEN=<new>
#   CLOUDFLARE_ANALYTICS_TOKEN=<new>
#   CLOUDFLARE_IDP_MGMT_TOKEN=<new>
# Leave CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_TUNNEL_TOKEN, POCKETID_* unchanged.
chmod 600 .env
```

### 3. Restart consumers

The bundle is sourced by various scripts. Most don't run as long-lived
services — they pick up the new value on next invocation. Long-lived
consumers are typically declared via compose `env_file:` or by direct
`source` statements in shell scripts. Two-pass scan keeps it fast:

```bash
ssh netcup-full '
  echo "compose env_file consumers:"
  find /opt -maxdepth 4 -name "docker-compose*.yml" -type f 2>/dev/null \
    | xargs -I{} grep -l "/opt/secrets/cloudflare" {} 2>/dev/null
  echo "shell-source consumers:"
  find /opt -maxdepth 5 \( -name "*.sh" -o -name "*.bash" \) -type f 2>/dev/null \
    | xargs -I{} grep -l "/opt/secrets/cloudflare/.env" {} 2>/dev/null | head -20
'
```

Restart each long-lived consumer compose stack found in the first list.
The second list is informational — those scripts pick up the new value
on their next manual invocation; nothing to restart.

### 4. Smoke test (API tokens)

```bash
# CLOUDFLARE_API_TOKEN — basic Zone read
set -a; . /opt/secrets/cloudflare/.env; set +a
curl -sH "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  https://api.cloudflare.com/client/v4/user/tokens/verify | jq .success
# Expect: true

# CLOUDFLARE_IDP_MGMT_TOKEN — Access apps list
curl -sH "Authorization: Bearer $CLOUDFLARE_IDP_MGMT_TOKEN" \
  https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/access/apps?per_page=1 \
  | jq .success
# Expect: true (proves the new IDP token has Access scope)
```

### 5. Revoke the OLD API tokens at the CF dashboard

CF dashboard → API Tokens → for each of the four originals → Revoke.

## Steps — tunnel token (CLOUDFLARE_TUNNEL_TOKEN)

Different procedure because the consumer is `cloudflared`, and the new
token must be live in the tunnel daemon *before* the old one is
invalidated, or external ingress drops.

### A. Generate a new tunnel token

CF Zero Trust dashboard → Networks → Tunnels → select the relevant tunnel.

CF rotates tunnel tokens via the dashboard's "Rotate token" UI for the
tunnel:
1. Tunnel detail page → "Configure" → tab "Public Hostname" (or similar
   based on current CF UI).
2. Find the "Connect" or "Token" section → click "Refresh token" /
   "Rotate" — the dashboard will display the new token once.
3. Copy it.

### B. Update `cloudflared` on Netcup

```bash
ssh netcup-full
cd /root/cloudflared
cp .env .env.bak-pre-rotate-$(date -u +%Y%m%d-%H%M%S)  # path may differ — find with: grep -rl TUNNEL_TOKEN /root /opt
# Replace TUNNEL_TOKEN= with the new value
docker compose restart cloudflared  # or `systemctl restart cloudflared` if not Dockerized
```

### C. Verify ingress still works

```bash
sleep 8
curl -sI https://passwords.jeffemmett.com/ | head -2
curl -sI https://status.jeffemmett.com/ | head -2
docker logs --tail 20 cloudflared 2>&1 | grep -iE 'connected|registered|error'
```

If any 5xx appears here, **revert immediately**:
```bash
mv /root/cloudflared/.env.bak-pre-rotate-<TS> /root/cloudflared/.env
docker compose restart cloudflared
```

### D. Update the bundle .env to match

Once C is green, also update `CLOUDFLARE_TUNNEL_TOKEN` in
`/opt/secrets/cloudflare/.env` so the central stash stays canonical.

### E. Revoke the OLD tunnel token

CF Zero Trust → the same tunnel → revoke the prior token. Watch
`docker logs cloudflared` once more — should NOT log any errors.

## Cleanup

```bash
shred -u ~/.secrets/private/cloudflare-rotation-*.txt
cd ~/Github/dev-ops
./security/mark-rotated.sh cloudflare-tokens-bundle
git add security/secrets-inventory.yaml
git commit -m "security: rotate cloudflare-tokens-bundle (mark inventory)"
```

If `cloudflare-api-token` inventory entry was also touched (the standalone
one at `~/.cloudflare-credentials.env`), mark it too — the two entries
overlap by design (local vs server stash of the same provider).

## If something goes wrong

- **Tunnel drops** → revert tunnel token IMMEDIATELY (step C above).
  Every external service routes through that tunnel.
- **`Zone:Read` 401 from a script** → it has the stale `CLOUDFLARE_API_TOKEN`.
  Grep for the consumer: `ssh netcup-full 'grep -rln CLOUDFLARE_API_TOKEN /opt /root'`.
- **Backup-system R2 sync fails** → it uses `CLOUDFLARE_API_TOKEN` with
  R2 scope. Verify the new token has R2:Read/Edit, not just Zone:Read.

## Cross-references

- Inventory: `cloudflare-tokens-bundle`, `cloudflare-api-token`,
  `pocketid-api-key` (separate but co-located in this file).
- Memory: [Netcup CF tunnel uses remote ingress config](../../../.claude/projects/-home-jeffe-Github-dev-ops/memory/cf_tunnel_remote_ingress.md)
- Related: TASK-low.7 (CF Access app on VW /admin — uses `CLOUDFLARE_IDP_MGMT_TOKEN`).
