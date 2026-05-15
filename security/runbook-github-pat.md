# Runbook: rotate GitHub personal access token

**Cadence**: 180 days. Inventory entry: `github-pat`.

PAT covers `gh` CLI auth and any scripts that talk to the GitHub API. If
the `gitea-github-mirror-token` is a separate (recommended) PAT, this
rotation does NOT touch it — that one is rotated under its own runbook
because it gates ~50+ repo mirrors and the rotation touches each repo
config individually.

> **PROVEN PATH (set 2026-05-15):** This was migrated to the gh
> device-flow OAuth token. The old `~/.secrets/private/github_token`
> shadow file was deleted (gh now manages the token natively in
> `~/.config/gh/hosts.yml`). **Future rotations: just run the
> device-flow block below — skip the manual-PAT sections entirely
> unless you have a specific reason to mint a classic PAT.**
>
> ```bash
> # Pre-state + backup (the shadow file no longer exists, so this is
> # informational only after the 2026-05-15 migration):
> gh auth status
>
> # The one human step (~30s): open the printed URL, enter the code:
> gh auth logout --hostname github.com
> gh auth login --hostname github.com --git-protocol ssh \
>   --scopes 'repo,admin:repo_hook,read:org,gist' --web
>
> # Verify + smoke test:
> gh auth status
> gh api user --jq .login
> gh repo list <your-gh-account> --limit 3
> gh api user/orgs --jq '.[].login' | head -3
>
> # Record:
> cd ~/Github/dev-ops && ./security/mark-rotated.sh github-pat
> git add security/secrets-inventory.yaml && git commit -m \
>   "security: rotate github-pat (mark inventory)"
> ```
>
> Note: device flow adds `admin:public_key` to the scope set (for SSH
> key management) — that's an expected, acceptable superset.

---

The manual-PAT material below is retained for the rare case you need a
classic or fine-grained PAT specifically (e.g. a token for a CI system
that can't do device flow).

**Historical token state (pre-2026-05-15):** classic PAT (prefix `gho_…`)
with scopes `admin:repo_hook, gist, read:org, repo`. Two options were:
- **Same shape (classic):** click "Regenerate token" on the existing
  one — fastest, identical scope, identical behaviour.
- **Migrate to fine-grained:** create a new fine-grained PAT, set
  expiration to 6 months, pick the equivalent permissions per the
  table below, and decommission the classic one. More work but
  significantly tighter blast radius.

| Classic scope | Fine-grained equivalent |
|---|---|
| `repo` | Repository permissions → Contents:Read+Write, Issues:Read+Write, Pull requests:Read+Write, Metadata:Read |
| `admin:repo_hook` | Repository permissions → Webhooks:Read+Write |
| `read:org` | Organization permissions → Members:Read |
| `gist` | Account permissions → Gists:Read+Write |

This runbook below is written for the classic-keeps-classic path. For
migration, substitute "Fine-grained tokens" everywhere and pick the
equivalents above.

## Pre-flight

- GitHub token settings page open:
  <https://github.com/settings/personal-access-tokens>
- Confirm `gh` CLI auth status:
  ```bash
  gh auth status
  # Logged in to github.com as <user> using TOKEN
  ```
- Current token (for reference, you'll need to update its consumers):
  ```bash
  cat ~/.secrets/private/github_token | head -c 8; echo "...(redacted)"
  ```

## Steps

### 1. Create the replacement PAT

GitHub → Settings → Developer Settings → Personal access tokens →
Fine-grained tokens → "Generate new token".

- Name: `<user>-rotated-YYYY-MM-DD`.
- **Expiration**: 6 months (matches our cadence — set the calendar reminder
  in `last_rotated` of the inventory entry).
- **Repository access**: copy from the prior token's scope. If you're
  not sure, the easiest is "All repositories" — but that's broad.
  Prefer "Selected repositories" and list the active set.
- **Permissions** (typical for a dev token):
  - Contents: Read+Write
  - Pull requests: Read+Write
  - Issues: Read+Write
  - Metadata: Read (auto-required)
  - Workflows: Read+Write (if you trigger Actions)
  - Webhooks: Read (if you debug webhook deliveries)
- Click "Generate token". **Copy the value once**; save to
  `~/.secrets/private/github_token.new` (mode 600).

### 2. Update local consumers

```bash
NEW_PAT=$(cat ~/.secrets/private/github_token.new)

# Canonical file:
cp ~/.secrets/private/github_token ~/.secrets/private/github_token.bak.$(date -u +%Y%m%d-%H%M%S)
echo -n "$NEW_PAT" > ~/.secrets/private/github_token
chmod 600 ~/.secrets/private/github_token

# gh CLI auth (re-login with new token from stdin):
echo "$NEW_PAT" | gh auth login --hostname github.com --git-protocol https --with-token

# Verify:
gh auth status
gh api user | jq -r .login
```

### 3. Update any scripts / env files holding the PAT

```bash
# Find shadow copies — local (fast: shell rc + known config locations)
grep -RIln 'GITHUB_TOKEN\|GH_TOKEN\|github_token' \
  ~/.bashrc ~/.zshrc ~/.config/fish/config.fish \
  ~/.npmrc ~/.config/gh/ 2>/dev/null

# Find shadow copies — on Netcup. Two-pass approach to keep it fast:
# Pass 1: compose env_file declarations (typical consumer pattern)
ssh netcup-full 'find /opt -maxdepth 4 -name "docker-compose*.yml" -type f 2>/dev/null \
  | xargs -I{} grep -l "GITHUB_TOKEN\|GH_TOKEN" {} 2>/dev/null | head -20'
# Pass 2: direct env_file references — only inside known .env locations
ssh netcup-full 'find /opt -maxdepth 4 -name ".env" -type f 2>/dev/null \
  | xargs -I{} grep -l "^GITHUB_TOKEN\|^GH_TOKEN" {} 2>/dev/null | head -20'
```

For each match, update the value:
- `~/.config/gh/hosts.yml` — `gh auth login` handles this (step 2).
- `~/.npmrc` — `//npm.pkg.github.com/:_authToken=<new>`.
- Service `.env` files (if any) — `sed -i` like the other runbooks.

### 4. Smoke test

```bash
# Authenticated request — checks the token works
gh api user | jq -r '.login'      # → your username

# Repo write (cheap operation: list pulls)
gh pr list --repo jeffemmett/dev-ops --limit 1

# If you have a script that uses GITHUB_TOKEN:
GITHUB_TOKEN=$NEW_PAT bash -c 'gh repo view jeffemmett/dev-ops | head -3'
```

### 5. Revoke the OLD PAT

GitHub → Settings → Developer Settings → PATs → click the old token →
"Revoke".

If a tool still has it, it will start 401-ing now. That's the signal to
find the shadow copy and update.

### 6. Cleanup + record

```bash
shred -u ~/.secrets/private/github_token.new
cd ~/Github/dev-ops
./security/mark-rotated.sh github-pat
git add security/secrets-inventory.yaml
git commit -m "security: rotate github-pat (mark inventory)"
```

## If something goes wrong

- **`gh: Bad credentials`** → `gh auth status` and re-run step 2.
- **A git push fails with 403** → HTTPS push uses the PAT. `git
  credential reject https://github.com && gh auth setup-git` re-binds.
- **CI Actions break** → the PAT might be used as a repo secret too.
  Check repo Settings → Secrets → Actions; update `GH_TOKEN` (or
  whatever name you set) there too.
- **Suspect compromise** → revoke immediately. GitHub also has the
  audit log at <https://github.com/settings/security-log> — review for
  unexpected token-creation or repo events.

## Cross-references

- Inventory: `github-pat`
- Distinct from: `gitea-github-mirror-token` (different PAT, broader
  blast radius; its runbook rotates the value across every Gitea
  mirrored repo).
