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

---

## Dated rotation-snapshot files

### `rspace-env-secrets-2026-05-05.txt`
Snapshot of rspace-online env values produced during the 2026-05-05
rotation batch. Per-key inventory entries (or per-file: the live `.env`
on Netcup) are the rotatable units; this snapshot is a record.

### `rspace-rapp-keys-2026-05-05`
Same — record of the 2026-05-05 rspace rapp key generation.

---

## Effectively-never-rotated values

### `relos-release.keystore`
Android release-signing keystore for Relos. Android requires the same
signing key across an app's lifetime — rotating it breaks the upgrade
path for every installed instance. Treated as a once-per-incident
artifact; rotation only on confirmed compromise. Keep in `~/.secrets/`
with strong file-mode (chmod 600) and consider an off-machine backup
to a hardware-protected store. Not in cadence.
