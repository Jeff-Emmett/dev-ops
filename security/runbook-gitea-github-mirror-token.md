# Runbook: rotate the Gitea→GitHub mirror token

**Cadence**: 365 days. Inventory entry: `gitea-github-mirror-token`.

A GitHub PAT that Gitea's repo-mirroring uses to **push** every
Gitea-primary repo out to its GitHub mirror. High fanout: the value is
configured on each mirrored repo's push-mirror settings in Gitea
(~50+ repos). Distinct from `github-pat` (your interactive gh CLI auth)
and `gitea-api-token` (deploy-webhook's Gitea API token).

> Why this is bespoke, not the shared external-api-key pattern: the
> consumer isn't a `.env` — it's a `config.secret`-style value stored
> per-repo inside Gitea's DB (the push-mirror remote). Updating it means
> touching every mirrored repo's mirror config, and per memory
> `gitea_webhook_patch_bug` the Gitea API silently drops some secret
> fields — so the DB is the reliable update path.

## Pre-flight

```bash
# Which repos have a push-mirror? (count + list)
ssh netcup-full '
  printf "%s" "SELECT m.repo_id, r.name FROM push_mirror m JOIN repository r ON r.id=m.repo_id;" \
  | docker exec -i gitea-db psql -U gitea -d gitea -tA' | tee /tmp/mirrors.txt | wc -l
```
The `push_mirror` table stores `remote_address` with the token embedded
in the URL (`https://<user>:<TOKEN>@github.com/...`), OR a separate
`remote_username`/`remote_password`-style column depending on Gitea
version (1.24.x: token is in the remote address of the mirror remote in
the git config of each repo, plus the `push_mirror` row). Confirm the
shape on this instance before scripting:
```bash
ssh netcup-full 'printf "%s" "\d push_mirror" | docker exec -i gitea-db psql -U gitea -d gitea'
```

## Steps

### 1. Create the new GitHub PAT
GitHub → Settings → Developer settings → Fine-grained tokens (or
classic). Scope: **Contents: Read+Write** on the mirrored repos (or
"All repositories" if the mirror set is broad). Name
`gitea-mirror-rotated-YYYY-MM-DD`. Copy once.

### 2. Update every push-mirror
Gitea UI is per-repo and tedious for 50+. Faster + reliable (per the
webhook-patch-bug lesson — use the DB, not the API):
```bash
# Inspect one row first to learn the exact column holding the token:
ssh netcup-full 'printf "%s" "SELECT * FROM push_mirror LIMIT 1;" \
  | docker exec -i gitea-db psql -U gitea -d gitea -x'
# Then UPDATE the token in-place (column name from above — often the
# remote is re-resolved from repo git config, so you may also need to
# rewrite each repo's .git/config remote URL). For the common case
# where push_mirror has a credential column:
#   UPDATE push_mirror SET <token_col> = '<NEW>' WHERE <token_col> = '<OLD>';
# piped via stdin (NOT psql -c — nested-quote trap, see memory
# python_heredoc_yaml_backticks):
printf '%s' "UPDATE push_mirror SET <col>='<NEW>' WHERE <col>='<OLD>';" \
  | ssh netcup-full 'docker exec -i gitea-db psql -U gitea -d gitea'
```
If the token lives in each repo's git remote URL instead, iterate:
```bash
ssh netcup-full '
  for d in /opt/gitea-data/git/repositories/*/*.git; do
    git -C "$d" remote -v | grep -q github.com && \
    git -C "$d" remote set-url --push github \
      "https://<user>:<NEW>@github.com/$(basename $(dirname $d))/$(basename $d .git).git"
  done'
```
(Exact paths depend on the Gitea data layout — verify with one repo
before looping.)

### 3. Trigger a mirror push + verify
Pick one active repo, push a trivial commit to Gitea, watch it land on
GitHub. Or in Gitea UI → that repo → Settings → Mirror → "Synchronize
Now" and confirm success (no auth error in the mirror log).

### 4. Revoke the OLD GitHub PAT
Only after a successful mirror push on the new token.

### 5. Record
```bash
cd ~/Github/dev-ops && ./security/mark-rotated.sh gitea-github-mirror-token
git add security/secrets-inventory.yaml && git commit -m "security: rotate gitea-github-mirror-token"
```

## If something goes wrong
- **Some repos still fail to mirror** → they kept the old token (missed
  a row / a git remote). Re-run step 2's loop; the failing repo's mirror
  log names it.
- **Revoked too early** → mirrors 403; mint a new PAT, redo step 2,
  revoke the interim.
- **Gitea API tempting but** — per `gitea_webhook_patch_bug` memory the
  PATCH endpoint silently drops some secret fields. Trust the DB/git
  path, verify with an actual push.

## Cross-references
Memory `gitea_webhook_patch_bug` (why DB not API),
`python_heredoc_yaml_backticks` (stdin-pipe SQL), distinct from
`github-pat` + `gitea-api-token` entries.
