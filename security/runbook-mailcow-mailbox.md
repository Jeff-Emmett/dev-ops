# Runbook: rotate a Mailcow mailbox password (shared pattern)

**Applies to** these inventory entries (all `mode: manual` — Mailcow OSS
has no programmatic mailbox-password API, the admin UI is the only path):

| Inventory entry | Mailbox | Canonical file | Consumers |
|---|---|---|---|
| `claude-jeffemmett-mailcow` | `claude@jeffemmett.com` | `~/.secrets/private/claude_jeffemmett_password` | claude-mail-agent, backlog-reply-handler, the postfix-sendmail path |
| `rmail-noreply-password` | `noreply@rmail.online` | `~/.secrets/private/rmail_noreply_password` | legacy senders — audit before rotating |
| `rmail-team-password` | `team@rmail.online` | `~/.secrets/private/rmail_team_password` | legacy (backlog notifs pre-2026-03) — likely waivable |

> One runbook because the flow is identical for every Mailcow mailbox.
> The `mailcow-smtp-stash` entry (`/opt/secrets/mailcow/.env`) bundles
> the CL mailbox password too — if you rotate `claude@` here, also
> update that stash; see `runbook-mailcow-smtp-stash.md`.

## Pre-flight

```bash
# Confirm the mailbox is actually still consumed before rotating a legacy one
grep -RIl '<password-file-basename>' ~/.secrets ~/Github/dev-ops/agents 2>/dev/null
ssh netcup-full 'find /opt -maxdepth 4 -name ".env" 2>/dev/null \
  | xargs -I{} grep -l "<MAILBOX_LOCALPART>" {} 2>/dev/null'
# rmail-team / rmail-noreply: if nothing consumes them → waive (WAIVED.md), don't rotate.
```

## Steps

### 1. Generate the new password
```bash
NEW=$(openssl rand -base64 24)   # listmonk/postfix accept this fine
```

### 2. Set it in the Mailcow admin UI
- <https://mail.rmail.online/admin> → Mail Setup → Mailboxes
- Edit the target mailbox → set password to `$NEW` → Save.
- (No API in OSS Mailcow — UI is mandatory.)

### 3. Update the canonical file + consumers
```bash
f=~/.secrets/private/<password-file>
cp "$f" "$f.bak.$(date -u +%Y%m%d-%H%M%S)"
printf '%s' "$NEW" > "$f"; chmod 600 "$f"

# Consumer .env files (claude@ example):
#   dev-ops/agents/claude-mail-agent/.env
#   Netcup: agents/backlog-reply-handler env / Infisical
# sed -i 's|^SMTP_PASS=.*|SMTP_PASS='"$NEW"'|' <each consumer .env>
# Restart each consumer container.
```

### 4. Smoke test — send a mail through the rotated mailbox
```bash
ssh netcup-full '
  printf "From: <mbox>\nTo: jeffemmett@gmail.com\nSubject: rotation test\n\nok\n" \
  | docker exec -i mailcowdockerized-postfix-mailcow-1 sendmail -f "<mbox>" jeffemmett@gmail.com
'
# Check inbox. For an authenticated-SMTP consumer, trigger its real send path
# and watch: docker logs <consumer> | grep -i "535\|auth"
```

### 5. Record
```bash
cd ~/Github/dev-ops
./security/mark-rotated.sh <inventory-entry>
git add security/secrets-inventory.yaml && git commit -m "security: rotate <entry> (mark inventory)"
```

## If something goes wrong
- **`535 5.7.8 authentication failed`** from a consumer → it still has the
  old password. Find it (pre-flight greps), update, restart.
- **Mail not delivered** → `docker logs mailcowdockerized-postfix-mailcow-1`;
  `SASL authentication failed` = wrong pw, not a delivery problem.
- **Rotated a legacy mailbox nothing uses** → fine, but consider waiving
  the entry instead (move to WAIVED.md) so the digest stops nagging.

## Cross-references
- `runbook-mailcow-smtp-stash.md` (the multi-account /opt/secrets stash)
- Memory: `~/.claude/CLAUDE.md` EMAIL section (postfix-sendmail trick),
  [Mailcow ACME recovery](../../../.claude/projects/-home-jeffe-Github-dev-ops/memory/mailcow_acme_recovery.md)
