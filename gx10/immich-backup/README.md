# immich backup: R2 → Hetzner migration

GX10 (`spark-be57`) backs up the immich library (~468 GiB, incl. phone uploads
under `library/upload`) via restic. **Migrating off the shared R2 repo onto a
dedicated repo on the Hetzner Storage Box** to cut R2 storage cost (immich is
the single largest object set in the R2 `netcup-backups` repo).

## Repos

| | Repo | Writer | Retention |
|---|---|---|---|
| **Old (R2)** | `s3:…/netcup-backups` (shared) | gx10 + netcup | netcup nightly `forget --group-by host --prune` |
| **New (Hetzner)** | `sftp:hetzner-box:immich-backups` (dedicated) | gx10 only | gx10 nightly `forget`, weekly `prune` (Sundays) |

Hetzner repo password + `RESTIC_REPOSITORY` live in `~/.hetzner_backup_credentials`
on gx10 (mode 600, NOT in git). SSH host `hetzner-box` → `u521871.your-storagebox.de:23`.

## Files

- `immich-backup.sh` — **new** nightly script (Hetzner target + self-managed
  retention). Staged on gx10 as `~/immich-backup.sh.hetzner`; becomes the active
  `~/immich-backup.sh` at cutover. Cron unchanged: `30 4 * * *`.
- `immich-hetzner-firstbackup.sh` — original one-shot full seed. **Superseded by
  the guard** (it had no reboot recovery — see history below).
- `immich-hetzner-seed-guard.sh` — **idempotent self-healing seed.** No-ops once
  a `gx10-immich` snapshot exists; else clears stale locks and (re)launches the
  seed detached. Cron `*/30 * * * *` so a mid-seed reboot self-recovers within
  30 min. restic resumes from already-uploaded blobs via dedup. **Remove the
  cron line + script at cutover.**
- `immich-hetzner-cutover.sh` — run after the seed completes: verifies the
  Hetzner repo (`restic check` + 5% data subset), then swaps the nightly script.
  Does NOT touch R2.

## History

- 2026-06-27 14:11 EDT — first seed launched. Uploaded ~206 GiB.
- 2026-06-29 10:26 EDT — **gx10 power-cycled** → systemd SIGTERM'd the seed mid
  run (`signal terminated received` / ssh exit 255). No snapshot saved; one
  stale lock left. R2 nightly kept running, so no backup gap.
- 2026-06-29 ~20:07 EDT — added `immich-hetzner-seed-guard.sh` (+ `*/30` cron),
  cleared the lock, resumed the seed from the 206 GiB partial.

## Procedure

1. **Seed** (in progress, self-healing via guard): resumes from partial; ~262
   GiB / ~10h remaining. The `*/30` guard cron restarts it after any reboot.
2. **Verify + cutover**: when the seed completes (a `gx10-immich` snapshot
   appears), run `~/immich-hetzner-cutover.sh` on gx10. It verifies integrity and
   swaps the nightly script R2 → Hetzner. **Then remove the seed-guard cron + script.**
3. **Drop immich from R2** (separate, destructive, confirm first):
   ```bash
   source ~/.r2_backup_credentials
   restic forget --host spark-be57 --prune   # frees ~468 GiB from R2
   ```
   Removes all 12 `spark-be57` snapshots (4× gx10-immich + 8× gx10-apps) from
   the shared R2 repo. apps is trivial and also in Gitea.
4. **Monitoring**: point the netcup `backup-healthcheck.sh` immich freshness
   check at the Hetzner repo (it currently checks the R2 `gx10-immich` tag) +
   add a Kuma push. TODO.

## Retention note

`restic forget --group-by host --keep-daily N` keeps only the LATEST snapshot
per day per host. gx10 writes apps-then-library nightly → library (last) wins
the daily slot; apps yields it. This is intentional — see
`immich_gx10_keepdaily_eviction` memory.
