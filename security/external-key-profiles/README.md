# External-key propagation profiles

Provider-minted secrets (API keys/tokens) can't be minted by a script — a
human creates the new value in the provider console. `../propagate-external-key.sh`
automates everything *after* that: fan the new value out to every consumer,
restart long-lived ones, smoke-test, mark the inventory.

Each profile = one inventory entry. Contract (see the script header for the
authoritative version):

```bash
INVENTORY_NAME="fal-api-key"
KEY_REGEX='^...$'                 # optional anchored ERE to catch paste errors
CONSUMERS=( "<host>|<path>|<var>" )   # host=local|netcup; var=__FILE__ or VARNAME
RESTART=( "<host>|<shell cmd>" )      # optional
SMOKE='<cmd using $NEW, must exit 0>' # optional but recommended
```

## Usage
```bash
# 1. Mint the new key in the provider console → save to a mode-600 temp file.
# 2. Propagate:
./propagate-external-key.sh --dry-run --key-file /tmp/new.key fal-api-key   # preview
./propagate-external-key.sh           --key-file /tmp/new.key fal-api-key   # apply
shred -u /tmp/new.key
# 3. Revoke the OLD key in the provider console (the script reminds you).
```

The new value is read from stdin/--key-file only — never argv (which leaks
into shell history, `ps`, and logs).

## Coverage
Start a profile for any `runbook-external-api-key.md` entry as you next rotate
it; the runbook's consumer table has the paths. Built so far: fal, runpod.
