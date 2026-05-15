# Runbook: periodic coverage audit (meta-entries, NOT a rotation)

**Applies to** the two inventory entries that aren't credentials — they
exist to make the weekly digest nag a *review*, not a key swap:

| Inventory entry | Audit |
|---|---|
| `netcup-service-envs` | Regenerate + diff the Netcup .env index |
| `infisical-projects-audit` | Review the Infisical project/migration estate |

> `mark-rotated.sh <entry>` here means "I did the review", not "I
> rotated a secret". Cadence: 90d each.

## netcup-service-envs

```bash
cd ~/Github/dev-ops
./security/dump-netcup-envs.sh                       # regenerates the doc
git diff security/netcup-service-envs.md             # what changed?
```
Inspect the diff for:
- **New services** with plain (non-Infisical) secrets → do they need
  their own inventory entry? Add it.
- **Services that gained `INFISICAL_*`** → migrated; fine.
- **Removed services** → decommissioned; prune any stale inventory entry.

Then: `./security/mark-rotated.sh netcup-service-envs` + commit (the
regenerated doc + the inventory bump together).

## infisical-projects-audit

```bash
$EDITOR ~/Github/dev-ops/infisical/inventory.yaml    # 63 projects, status
```
- Are `pending` migrations still pending on purpose, or stalled?
- Spot-check 5 random `migrated` projects in the Infisical UI: do their
  identities/service-tokens still exist and authenticate? (A migrated
  service whose Infisical identity was deleted is silently broken.)
- Any project in Infisical with no corresponding running service →
  candidate for deletion (reduce attack surface).

Then: `./security/mark-rotated.sh infisical-projects-audit` + commit.

## Why these are in the rotation inventory at all
The digest is the only periodic forcing function we have. Piggy-backing
"review coverage" on it means the secret universe can't silently drift
out from under the pipeline. They're flagged as audits in their entry
`notes:` so a future operator doesn't mistake them for credentials.

## Cross-references
`security/dump-netcup-envs.sh`, `security/netcup-service-envs.md`,
`infisical/inventory.yaml`, `runbook-infisical-service-token.md`.
