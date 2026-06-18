# Secrets explicitly excluded from the rotation inventory

Companion to `secrets-inventory.yaml`. The rotation digest only flags
entries in the inventory; this file records *why* certain values were
considered and deliberately left out.

Pattern: short rationale per entry. If the rationale stops being true
(secret becomes active, becomes rotatable, becomes load-bearing), move
the entry into `secrets-inventory.yaml` and remove it here.

---

## Non-credentials misfiled in `~/.secrets/private/`

### `netcup_ip`
Just the Netcup VPS IPv4 address — public information, not a secret.
Kept in the secrets dir for convenience of grep/`cat` against `ssh netcup`
config. Don't rotate.

### `syncthing_netcup_device_id`
Syncthing device IDs are public-by-design identifiers exchanged at peer
pairing. Not a credential. Stored alongside actual API keys for grouping;
not rotated. (The two `syncthing_*_api_key` files are real credentials
and *are* in the inventory.)

---

## Stale backups of already-rotated values

### `claude_jeffemmett_password.bak-20260421-1140`
Pre-2026-04-21 backup of the `claude_jeffemmett_password` value. The live
secret was rotated on 2026-04-21 (`last_rotated` on inventory entry
`claude-jeffemmett-mailcow`). Backup retained for emergency rollback;
should be deleted when no longer needed. Not under rotation cadence.

### `github_token`, `syncthing_local_api_key`, `syncthing_netcup_api_key` (removed)
These were `~/.secrets/private/` *cache copies* of values whose canonical
source lives elsewhere — `github_token` shadowed the gh-managed OAuth
token (`~/.config/gh/hosts.yml`); the two `syncthing_*` files shadowed
the `<gui><apikey>` element in each instance's `config.xml`. All three
were removed once their rotations made the caches stale (2026-05-15);
timestamped `.bak-*` copies retained. The inventory entries
(`github-pat`, `syncthing-{local,netcup}-api-key`) now point at the real
source. Don't recreate the cache files — they only cause drift.

---

## Dated rotation-snapshot files

### `rspace-env-secrets-2026-05-05.txt`
Snapshot of rspace-online env values produced during the 2026-05-05
rotation batch. Per-key inventory entries (or per-file: the live `.env`
on Netcup) are the rotatable units; this snapshot is a record.

### `rspace-rapp-keys-2026-05-05`
Same — record of the 2026-05-05 rspace rapp key generation.

---

## Services not currently deployed (rotation N/A until restarted)

Waived 2026-06-18. These had inventory entries but **no container exists**
(running or stopped) and the DB can't be `ALTER USER`'d while down. The `.env`
files still exist on Netcup, so the secrets aren't gone — just dormant. **If the
service is redeployed, move the entry back into `secrets-inventory.yaml`** and
do the listmonk-incident same-`${VAR}` check (app + postgres share the var →
add a `postgres-profile` + `mode: auto`; split-config → manual lockstep).
Tracked under TASK-89 AC #3.

### `rnotes-database`
rnotes (rspace-online sub-app). `/opt/secrets/rnotes/.env` exists (mtime
2026-02-13); no `rnotes` container. Not deployed.

### `mattermost-postgres`
`/opt/apps/mattermost/.env` exists (mtime 2026-02-13); no `mattermost`
container. Stack stopped/undeployed.

### `cyclos-postgres`
Cyclos mutual-credit platform. `/opt/apps/cyclos/.env` exists (mtime
2026-04-15); no `cyclos` container. Stack stopped/undeployed.

---

## Effectively-never-rotated values

### `relos-release.keystore`
Android release-signing keystore for Relos. Android requires the same
signing key across an app's lifetime — rotating it breaks the upgrade
path for every installed instance. Treated as a once-per-incident
artifact; rotation only on confirmed compromise. Keep in `~/.secrets/`
with strong file-mode (chmod 600) and consider an off-machine backup
to a hardware-protected store. Not in cadence.
