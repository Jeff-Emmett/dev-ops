# Runbook: rotate <SECRET-NAME>

**Cadence**: <N> days. Inventory entry: `<inventory-name>`.

<1-2 sentence framing — blast radius, who breaks if this goes wrong, what
makes this rotation different from a normal one.>

## Pre-flight

- Have the provider console open: <https://...>
- Capture current state for rollback evidence:
  ```bash
  # Note current Last-Used or active-token-IDs if the portal exposes them.
  ```
- Check for in-flight work that would break on a key swap:
  ```bash
  ssh netcup 'docker ps --format "..." | grep -iE "..."'
  ```

## Steps

### 1. Create the new value at the provider

<Specific clicks/commands. Always create NEW before invalidating OLD —
gives you a clean rollback.>

### 2. Update consumers — local first, then Netcup

```bash
NEW_VAL=$(cat ~/.secrets/private/<name>.new)

# Local
for f in <list>; do
  cp "$f" "$f.bak.$(date -u +%Y%m%d-%H%M%S)"
  sed -i "s|^<VAR>=.*|<VAR>=${NEW_VAL}|" "$f"
done

# Netcup
for f in <list>; do
  ssh netcup-full "cp $f $f.bak.\$(date -u +%Y%m%d-%H%M%S) && \\
    sed -i 's|^<VAR>=.*|<VAR>=${NEW_VAL}|' $f"
done
```

### 3. Restart services so they pick up the new value

```bash
ssh netcup-full 'cd /opt/apps/<svc> && docker compose up -d'
```

### 4. Smoke test

<One concrete command that should succeed with the NEW value AND
fail/401 with the OLD value. The whole point of the test.>

### 5. Revoke the OLD value at the provider

<Only after smoke test passes. If a service was missed in step 2/3,
it will break here — that's the signal to find and fix.>

### 6. Clean up + record

```bash
shred -u ~/.secrets/private/<name>.new
cd ~/Github/dev-ops
./security/mark-rotated.sh <inventory-name>
git add security/secrets-inventory.yaml
git commit -m "security: rotate <inventory-name> (mark inventory)"
```

## If something goes wrong

- **A service 401s after rotation**: it has a stale value. Re-run step 2
  for that service's .env. If you can't find where the stale value lives:
  ```bash
  ssh netcup-full 'grep -rl "<VAR>" /opt/apps/ /opt/'
  ```
- **You revoked too early**: create another new value (step 1) and re-run.
- **Suspect compromise**: revoke immediately, accept downtime, rotate
  cleanly. Brief outage beats continued misuse.

## Cross-references

- [Inventory entry](secrets-inventory.yaml) — search for `name: <inventory-name>`
- Related runbooks: <if any chain or share infrastructure>
