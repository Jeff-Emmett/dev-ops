# Runbook: rotate Mailcow SMTP credentials stash

**Cadence**: 180 days. Inventory entry: `mailcow-smtp-stash`.

`/opt/secrets/mailcow/.env` on Netcup holds shared SMTP creds for two
mailboxes (JE = jeffemmett@, CL = claude@) and Listmonk API/admin creds.
Many services source from this file; rotating means updating Mailcow
mailbox passwords AND every consumer in the same window.

The seven values:

| Var | Source of truth | What rotation means |
|---|---|---|
| `MAILCOW_SMTP_HOST` | mailcow.conf | not a secret; leave |
| `MAILCOW_SMTP_PORT` | 587 | not a secret; leave |
| `MAILCOW_SMTP_USER_JE` | mailbox name `jeffemmett@…` | rarely rotated — handle separately if needed |
| `MAILCOW_SMTP_PASS_JE` | Mailcow mailbox password | rotate via Mailcow admin UI |
| `MAILCOW_SMTP_USER_CL` | `claude@jeffemmett.com` | same |
| `MAILCOW_SMTP_PASS_CL` | Mailcow mailbox password | rotate via Mailcow admin UI |
| `LISTMONK_API_USER` | Listmonk API user name | rarely rotated |
| `LISTMONK_API_TOKEN` | Listmonk-generated API token | rotate via Listmonk admin UI |
| `LISTMONK_ADMIN_USER` | Listmonk admin user | rarely rotated |
| `LISTMONK_ADMIN_PASS` | Listmonk admin password | rotate via Listmonk UI |

The Mailcow CL (`claude@`) password is ALSO tracked separately as the
canonical `claude-jeffemmett-mailcow` inventory entry — coordinate the two.

## Pre-flight

- Mailcow admin UI: <https://mail.rmail.online/admin>
- Listmonk admin (find URL): `ssh netcup 'docker ps | grep listmonk'`
- Identify consumers (two-pass to keep it fast; recursive `grep` over
  /opt times out due to volume):
  ```bash
  ssh netcup-full '
    echo "compose env_file consumers:"
    find /opt -maxdepth 4 -name "docker-compose*.yml" -type f 2>/dev/null \
      | xargs -I{} grep -l "/opt/secrets/mailcow" {} 2>/dev/null
    echo "shell-source consumers:"
    find /opt -maxdepth 5 \( -name "*.sh" -o -name "*.bash" \) -type f 2>/dev/null \
      | xargs -I{} grep -l "/opt/secrets/mailcow/.env" {} 2>/dev/null | head -20
  '
  # Expected: postiz tenants, any agents/scripts that ship mail.
  ```
- Backup baseline:
  ```bash
  ssh netcup-full 'cp /opt/secrets/mailcow/.env /opt/secrets/mailcow/.env.bak-pre-rotate-$(date -u +%Y%m%d-%H%M%S)'
  ```
- Confirm a test send works on the OLD creds before rotating:
  ```bash
  # See ~/.claude/CLAUDE.md EMAIL section for the sendmail-via-postfix trick
  ```

## Steps — Mailcow mailbox passwords

### 1. Generate new passwords

```bash
NEW_PASS_JE=$(openssl rand -base64 24)
NEW_PASS_CL=$(openssl rand -base64 24)
# Drop into ~/.secrets/private/mailcow-rotation-YYYY-MM-DD.txt for the duration
```

### 2. Update in Mailcow admin UI

Mailcow → Mail Setup → Mailboxes → edit `jeffemmett@…`:
- Set new password (paste `$NEW_PASS_JE`)
- Save

Repeat for `claude@jeffemmett.com` with `$NEW_PASS_CL`.

(Mailcow doesn't have a programmatic password-set API in OSS — UI only.)

### 3. Update the stash

```bash
NEW_PASS_JE=$(grep '^JE=' ~/.secrets/private/mailcow-rotation-*.txt | cut -d= -f2-)
NEW_PASS_CL=$(grep '^CL=' ~/.secrets/private/mailcow-rotation-*.txt | cut -d= -f2-)

ssh netcup-full "
  sed -i 's|^MAILCOW_SMTP_PASS_JE=.*|MAILCOW_SMTP_PASS_JE=${NEW_PASS_JE}|' /opt/secrets/mailcow/.env
  sed -i 's|^MAILCOW_SMTP_PASS_CL=.*|MAILCOW_SMTP_PASS_CL=${NEW_PASS_CL}|' /opt/secrets/mailcow/.env
"
```

### 4. Restart consumers

```bash
# Use the consumer list from pre-flight. For each compose_dir:
ssh netcup-full '
  for f in $(find /opt -maxdepth 4 -name "docker-compose*.yml" -type f 2>/dev/null \
              | xargs -I{} grep -l "/opt/secrets/mailcow" {} 2>/dev/null); do
    compose_dir=$(dirname "$f")
    echo "restarting $compose_dir"
    cd "$compose_dir" && docker compose up -d
  done
'
```

### 5. Update the standalone `claude-jeffemmett-mailcow` value

This is the master copy at `~/.secrets/private/claude_jeffemmett_password`
on the dev box. Per its own inventory entry — keep it in sync:

```bash
cp ~/.secrets/private/claude_jeffemmett_password \
   ~/.secrets/private/claude_jeffemmett_password.bak.$(date -u +%Y%m%d-%H%M%S)
echo -n "$NEW_PASS_CL" > ~/.secrets/private/claude_jeffemmett_password
chmod 600 ~/.secrets/private/claude_jeffemmett_password
```

Also update its consumers (claude-mail-agent, backlog-reply-handler) —
see `runbook-claude-jeffemmett-mailcow.md` for the full list.

### 6. Smoke test SMTP

Send a test email through one of the rotated services (e.g. trigger a
postiz tenant to schedule a test post that emits an SMTP notification),
OR send directly via the sendmail-in-postfix trick:

```bash
ssh netcup-full '
  printf "From: Claude <claude@jeffemmett.com>\nTo: jeffemmett@gmail.com\nSubject: post-rotation test\n\nIf you got this, SMTP rotation worked.\n" \
    | docker exec -i mailcowdockerized-postfix-mailcow-1 sendmail -f "claude@jeffemmett.com" "jeffemmett@gmail.com"
'
# Check your inbox.
```

## Steps — Listmonk API + admin

### A. Rotate the API token

Listmonk admin UI → Settings → Users → API users → select the user → roll token.

```bash
ssh netcup-full "
  sed -i 's|^LISTMONK_API_TOKEN=.*|LISTMONK_API_TOKEN=<new>|' /opt/secrets/mailcow/.env
"
```

### B. Rotate the admin password

Listmonk admin UI → Settings → Users → select your admin → reset password.

```bash
ssh netcup-full "
  sed -i 's|^LISTMONK_ADMIN_PASS=.*|LISTMONK_ADMIN_PASS=<new>|' /opt/secrets/mailcow/.env
"
```

### C. Restart Listmonk + its consumers

```bash
ssh netcup-full '
  cd /opt/apps/listmonk && docker compose up -d
  # Plus any clients of the Listmonk API
'
```

## Cleanup + record

```bash
shred -u ~/.secrets/private/mailcow-rotation-*.txt
cd ~/Github/dev-ops
./security/mark-rotated.sh mailcow-smtp-stash
./security/mark-rotated.sh claude-jeffemmett-mailcow  # because we touched it
git add security/secrets-inventory.yaml
git commit -m "security: rotate mailcow-smtp-stash + claude-jeffemmett-mailcow"
```

## If something goes wrong

- **SMTP 535 auth failure from a consumer** → mailbox password changed
  but consumer still has OLD. Find: `ssh netcup-full 'grep -rln MAILCOW_SMTP_PASS_CL /opt'`.
- **Test email not delivered** → check mailcow postfix logs:
  `ssh netcup-full 'docker logs --tail 30 mailcowdockerized-postfix-mailcow-1'`.
  Look for `SASL authentication failed` (wrong password) vs
  `connection refused` (network) vs `rejected` (rate limit / spam).
- **Listmonk token revoked too early breaks campaign send** → generate
  another via the same UI flow, update the stash, restart.

## Cross-references

- Inventory: `mailcow-smtp-stash`, `claude-jeffemmett-mailcow`,
  `rmail-noreply-password`, `rmail-team-password`
- Memory: [Email sending pattern](../../../.claude/projects/-home-jeffe-Github-dev-ops/memory/MEMORY.md) — `~/.claude/CLAUDE.md` EMAIL section has the postfix-sendmail trick.
- Related: [Mailcow ACME recovery](../../../.claude/projects/-home-jeffe-Github-dev-ops/memory/mailcow_acme_recovery.md)
