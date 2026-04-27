# Secret rotation pipeline

Single source of truth for every rotatable secret across the stack.

## Layout

```
security/
├── secrets-inventory.yaml          # registry of all secrets
├── rotate-<name>.sh                # automated rotation scripts
├── runbook-<name>.md               # manual rotation runbooks
├── check-rotation-due.sh           # weekly digest cron entrypoint
├── rotation-digest.service         # systemd unit
└── rotation-digest.timer           # weekly schedule
```

## How it works

1. **Inventory** (`secrets-inventory.yaml`) lists every secret, where it lives,
   what consumes it, and how often it should rotate. `last_rotated` is the
   ground truth for "when was this last touched."
2. **Rotation scripts** (`rotate-<name>.sh`) are idempotent, support `--dry-run`,
   and update `last_rotated` in the inventory atomically on success.
3. **Manual runbooks** (`runbook-<name>.md`) walk through rotations that can't
   be fully automated (Anthropic console, Cloudflare dashboard, etc.). Each
   runbook ends with a single command to update `last_rotated`.
4. **Weekly digest** — `rotation-digest.timer` fires `check-rotation-due.sh`
   every Monday 09:00 UTC. The script computes which secrets are within
   14 days of (`last_rotated` + `cadence_days`) and emails Jeff.

## Adding a new secret

1. Append an entry to `secrets-inventory.yaml`. Use an existing entry as a
   template; fields are documented at the top of the file.
2. If automated: write `rotate-<name>.sh` (use `rotate-gitea-webhook.sh`
   as the template — generates value, updates consumers, restarts services,
   tests, writes `last_rotated`).
3. If manual: write `runbook-<name>.md` with explicit commands.
4. Commit. The weekly digest picks it up automatically.

## Running a rotation

Auto:
```bash
./security/rotate-gitea-webhook.sh --dry-run    # preview
./security/rotate-gitea-webhook.sh              # do it
```

Manual:
```bash
$EDITOR security/runbook-anthropic-api-key.md   # follow steps
./security/mark-rotated.sh anthropic-api-key    # bump last_rotated when done
```

## Why this exists

TASK-53 surfaced that even after a leaked secret was rotated, there was no
record of the rotation, no list of consumers, no cadence, and no way to know
the leaked value was no longer the live secret. This pipeline closes that gap.
