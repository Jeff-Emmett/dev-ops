# Runbook: rotate a Vaultwarden admin token

**Inventory entries**:
- `vaultwarden-admin-token` — the LIVE passwords.jeffemmett.com instance.
  **This is `mode: auto`** → just run the proven script:
  ```bash
  cd ~/Github/dev-ops
  ./security/rotate-vaultwarden-admin-token.sh --dry-run
  ./security/rotate-vaultwarden-admin-token.sh
  ```
  (passphrase → argon2id via the container's `vaultwarden hash` → `$`→`$$`
  compose-escape → swap VW_ADMIN_TOKEN → compose up → loopback login
  test → mark-rotated. Proven live 2026-05-15.)

- `vaultwarden-admin-passphrase-commons-hub` — the **deferred** Commons
  Hub instance (commented out in `netcup/vaultwarden/docker-compose.yml`
  until `passwords.commons-hub.io` DNS exists). No running consumer yet.

## Commons Hub instance (this runbook's actual content)

Until the commons-hub Vaultwarden is deployed there's nothing to rotate
*against* — the passphrase just sits in
`~/.secrets/private/vaultwarden_admin_passphrase_commons-hub.txt`. Two
cases:

**Still deferred (current state):** rotating is low-value (no live
service). If the digest nags and the instance still isn't deployed,
either regenerate the local passphrase file for hygiene:
```bash
f=~/.secrets/private/vaultwarden_admin_passphrase_commons-hub.txt
cp "$f" "$f.bak.$(date -u +%Y%m%d-%H%M%S)"
openssl rand -base64 24 | tr -d '/+=' | head -c 32 > "$f"; chmod 600 "$f"
./security/mark-rotated.sh vaultwarden-admin-passphrase-commons-hub
```
…or `mark-rotated` with a note that it's deferred (defer the real
rotation until deploy). Don't compute/install an argon2 hash yet —
there's no .env to put it in.

**Once deployed:** it becomes structurally identical to the live
instance. Reuse the script with overrides:
```bash
LOCAL_PLAINTEXT=~/.secrets/private/vaultwarden_admin_passphrase_commons-hub.txt \
NETCUP_ENV=/opt/apps/vaultwarden/.env \
VW_HOST=passwords.commons-hub.io \
./security/rotate-vaultwarden-admin-token.sh
```
(adjust `NETCUP_ENV` / the compose service name to the commons-hub
container; verify the loopback Host header matches its Traefik rule).
At that point, flip the inventory entry to `mode: auto` pointing at the
script with those env overrides documented in its `notes:`.

## Cross-references
`rotate-vaultwarden-admin-token.sh`, memory
`docker_compose_dollar_escaping` (the `$`→`$$` argon2 trap),
TASK-82 / TASK-low.* (Vaultwarden deployment).
