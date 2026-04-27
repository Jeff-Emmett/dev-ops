# Runbook: rotate Anthropic API key

**Cadence**: 90 days. Inventory entry: `anthropic-api-key`.

This is one of the higher-blast-radius keys in the stack — it bills against
your Anthropic account and is used by services on Netcup, local dev tools,
and the Claude Code CLI itself. Rotation must be done in a specific order
to avoid breaking inflight work.

## Pre-flight

- Have the Anthropic console open: <https://console.anthropic.com/settings/keys>
- Make sure no long-running Claude Code session, agent, or batch job is
  mid-run that would be killed by an invalidated key. Check on Netcup:
  ```bash
  ssh netcup 'docker ps --format "{{.Names}}|{{.Status}}" | grep -iE "claude|anthropic|p2pwiki-ai|erowid|pentagi|unicart"'
  ```

## Steps

### 1. Create the new key in the Anthropic console

1. Sign in → API Keys → "Create Key".
2. Name it `prod-rotated-YYYY-MM-DD` so it's obvious in the audit log.
3. **Copy the value once** — it's not shown again. Store in
   `~/.secrets/private/anthropic_api_key.new` (mode 600) for the duration
   of this rotation, delete after.

### 2. Update local consumers (don't restart yet — these read on use)

```bash
NEW_KEY=$(cat ~/.secrets/private/anthropic_api_key.new)

# Workspace .env files
for f in \
  /home/jeffe/Github/p2pwiki-content/.env \
  /home/jeffe/Github/pentagi-deploy/.env
do
  cp "$f" "$f.bak.$(date -u +%Y%m%d-%H%M%S)"
  sed -i "s|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=${NEW_KEY}|" "$f"
done

# Shell env / Claude Code CLI — check these locations and update if present:
grep -RIn 'ANTHROPIC_API_KEY=' \
  ~/.bashrc ~/.zshrc ~/.config/fish/config.fish \
  ~/.claude/settings.json ~/.claude/.env 2>/dev/null
```

If `~/.claude/settings.json` has `env.ANTHROPIC_API_KEY`, update it. If you
use a credential helper (e.g. 1Password, KeePass), update the entry there
and re-shim.

### 3. Update Netcup consumers

```bash
NEW_KEY=$(cat ~/.secrets/private/anthropic_api_key.new)

# Push new value to each .env on Netcup
for f in \
  /opt/apps/erowid-bot/.env \
  /opt/apps/p2pwiki-ai/.env \
  /opt/apps/pentagi/.env \
  /opt/apps/unicart/.env
do
  ssh netcup-full "cp $f $f.bak.\$(date -u +%Y%m%d-%H%M%S) && sed -i 's|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=${NEW_KEY}|' $f"
done

# Restart the services so the new key is loaded into env
ssh netcup-full 'cd /opt/apps/erowid-bot && docker compose up -d'
ssh netcup-full 'cd /opt/apps/p2pwiki-ai && docker compose up -d'
ssh netcup-full 'cd /opt/apps/pentagi && docker compose up -d'
ssh netcup-full 'cd /opt/apps/unicart && docker compose up -d'
```

### 4. Smoke test

- Send a test prompt via Claude Code CLI: `claude -p "say ok"` — should return.
- Hit one of the rotated services and watch logs:
  ```bash
  ssh netcup 'docker logs --tail 40 -f p2pwiki-ai'
  ```
  Trigger a query against the public endpoint; confirm no 401 from Anthropic.

### 5. Revoke the OLD key in the Anthropic console

Only after smoke tests pass. Delete the previous key from the console so
it can no longer be used. If a service was missed in step 2/3, it will
break here — that's the signal to find and fix the missing consumer.

### 6. Clean up + record

```bash
shred -u ~/.secrets/private/anthropic_api_key.new
cd ~/Github/dev-ops
./security/mark-rotated.sh anthropic-api-key
git add security/secrets-inventory.yaml
git commit -m "security: rotate anthropic-api-key (mark inventory)"
```

## If something goes wrong

- **A service 401s after rotation**: it has a stale key. Re-run step 3 for
  that service's `.env` and restart. If you can't find where the stale key
  lives, search: `ssh netcup-full 'grep -rl "ANTHROPIC_API_KEY" /opt/apps/'`
- **You revoked too early**: just create another new key (step 1) and
  re-run from step 2.
- **Suspect compromise**: revoke immediately, accept downtime, then rotate
  cleanly. The risk of continued misuse beats the brief outage.
