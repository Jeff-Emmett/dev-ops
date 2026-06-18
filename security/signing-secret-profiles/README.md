# Signing-secret rotation profiles

For SELF-GENERATED secrets — signing/JWT/APP secrets, Directus KEY/SECRET,
internal tokens — where we choose the value, so rotation is fully automatable
(`../rotate-signing-secret.sh`). Contrast with `external-key-profiles/`
(provider-minted, can only propagate) and `postgres-profiles/` (DB passwords).

⚠ **Blast radius.** Rotating a token-signing secret invalidates every active
session / cached token for that service. Schedule + announce. Run by hand at a
chosen time; do NOT wire session-bearing secrets to an unattended timer.

Contract (authoritative version in the script header):
```bash
INVENTORY_NAME="..."
GEN='openssl rand -hex 32'              # optional; per-target generator
TARGETS=( "<host>|<path>|<VAR>" )       # each gets its OWN fresh value
RESTART=( "<host>|<cmd>" )              # recreate so new value is read
VERIFY='<health cmd, exit 0>'          # optional
```

## Usage
```bash
./rotate-signing-secret.sh --dry-run commons-hub-directus-app-secrets   # preview
# (announce the session-invalidation window, then:)
./rotate-signing-secret.sh           commons-hub-directus-app-secrets
```

## Where this fits the bundles
The `multi-secret-env` / `multi-tenant` inventory entries are *bundles*; their
signing-secret members (APP_SECRET, JWT_*, KEY/SECRET) are exactly this script's
job. Add a profile per bundle member as you rotate it. DB-password members use
`postgres-profiles/`; provider keys use `external-key-profiles/`.
