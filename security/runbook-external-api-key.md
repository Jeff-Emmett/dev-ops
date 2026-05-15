# Runbook: rotate an external-provider API key (shared pattern)

**Applies to** these inventory entries (all `mode: manual`, provider
portal is the source of truth — no script can mint these):

| Inventory entry | Provider portal | .env / consumer location |
|---|---|---|
| `moonshot-api-key` | platform.moonshot.cn → API keys | `~/.secrets/private/moonshot_api_key`; LiteLLM/agent configs |
| `fal-api-key` | fal.ai dashboard → Keys | `/opt/secrets/fal/.env` (`FAL_KEY`) |
| `runpod-api-key` | runpod.io → Settings → API Keys | `~/.secrets/private/runpod_api_key`; RunPod CLI/ssh-config |
| `vastai-api-key` | cloud.vast.ai → Account → API Key | `~/.secrets/private/vastai_api_key`; vastai CLI |
| `google-oauth-credentials` | console.cloud.google.com → APIs & Services → Credentials | `/opt/secrets/google/.env` |
| `porkbun-api-key` | porkbun.com/account/api | `~/.secrets/private/...`; DNS scripts |
| `pocketid-api-key` | self-hosted PocketID admin → API keys | `/opt/secrets/pocket-id/.env` |
| `resend-api-key` | resend.com/api-keys | `/opt/secrets/resend/.env` (likely legacy — see note) |

> One runbook because the flow is **identical** for all of them: the
> only thing that changes is the portal URL and the consumer list. For
> per-entry specifics, check the inventory entry's `consumers` block.

> **resend-api-key note:** per project memory, email senders migrated
> off Resend to Mailcow (Resend key expired Feb 2026). Before rotating,
> confirm it still has a live consumer; if not, *waive* it (move to
> WAIVED.md) instead of rotating a dead key.

## The pattern (substitute `<ENTRY>`, `<VAR>`, portal URL)

### 1. Pre-flight

```bash
# Who consumes it? (the inventory entry's consumers block is the index;
# this catches shadow copies)
grep -RIl '<VAR>' ~/.secrets ~/.config 2>/dev/null
ssh netcup-full 'find /opt -maxdepth 4 -name "*.env" 2>/dev/null \
  | xargs -I{} grep -l "<VAR>" {} 2>/dev/null'
```

### 2. Create the NEW key in the provider portal

- Log in → API Keys → Create.
- Name it `rotated-YYYY-MM-DD` so it's identifiable in the provider's
  audit log.
- **Copy the value once** → `~/.secrets/private/<entry>.new` (mode 600).
- Do NOT revoke the old key yet — it's your rollback.

### 3. Update consumers (local first, then Netcup)

```bash
NEW=$(cat ~/.secrets/private/<entry>.new)

# Canonical file (if the entry's location.type is file)
f=~/.secrets/private/<file>            # or /opt/secrets/<x>/.env on netcup
cp "$f" "$f.bak.$(date -u +%Y%m%d-%H%M%S)"
# single-value file:
printf '%s' "$NEW" > "$f"
# OR keyed .env line:
sed -i "s|^<VAR>=.*|<VAR>=$NEW|" "$f"

# Netcup .env consumers
ssh netcup-full "for f in <list>; do \
  cp \$f \$f.bak.\$(date -u +%Y%m%d-%H%M%S) && \
  sed -i 's|^<VAR>=.*|<VAR>=$NEW|' \$f; done"
```

### 4. Restart long-lived consumers

```bash
# Only services that hold the key in memory. Most CLIs/scripts re-read
# on next run — nothing to restart.
ssh netcup-full 'cd /opt/apps/<svc> && docker compose up -d'
```

### 5. Smoke test — prove the NEW key works AND the OLD is still around

A provider call that 200s with the new key. Examples:

```bash
# Generic bearer-style:
curl -sf -H "Authorization: Bearer $NEW" <provider-health-or-whoami-endpoint> | head -c 200

# fal:        curl -sf -H "Authorization: Key $NEW" https://fal.run/health
# runpod:     curl -sf https://api.runpod.io/graphql -H "Authorization: Bearer $NEW" -d '{"query":"{myself{id}}"}'
# resend:     curl -sf https://api.resend.com/domains -H "Authorization: Bearer $NEW"
# porkbun:    curl -sf -X POST https://api.porkbun.com/api/json/v3/ping -d "{\"apikey\":\"$NEW\",\"secretapikey\":\"$SECRET\"}"
```

### 6. Revoke the OLD key in the portal

Only after step 5 passes. If a consumer was missed in step 3 it 401s
now — that's the signal. Find it: `grep -RIl '<VAR>'` again (step 1).

### 7. Record

```bash
shred -u ~/.secrets/private/<entry>.new
cd ~/Github/dev-ops
./security/mark-rotated.sh <ENTRY>
git add security/secrets-inventory.yaml
git commit -m "security: rotate <ENTRY> (mark inventory)"
```

## If something goes wrong

- **Consumer 401s after rotation** → it has the stale value. Re-run
  step 3 for that consumer; if you can't find where it lives, the
  step-1 greps are the search.
- **Revoked too early** → create another new key (step 2), redeploy
  consumers, then revoke the intermediate one.
- **Suspect compromise** → revoke immediately in the portal, accept the
  outage, rotate cleanly. Brief downtime beats continued misuse; most
  of these providers also have their own anomaly alerts.

## When NOT to use this runbook

- Self-hosted services where you can mint tokens via CLI/DB without a
  browser → write a `rotate-*.sh` instead (see `rotate-gitea-api-token.sh`
  as the template; Gitea, PocketID-if-it-has-an-API, etc.).
- Anything whose app reads the credential from a config *separate* from
  the rotated file → needs a bespoke lockstep runbook (see
  `runbook-listmonk-postgres.md` for why).

## Cross-references

- `runbook-TEMPLATE.md` — the generic shape this specializes
- `runbook-anthropic-api-key.md`, `runbook-stripe-crypto-commons.md`,
  `runbook-cloudflare-tokens-bundle.md` — higher-stakes external keys
  that justified their own dedicated runbooks
