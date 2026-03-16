## Environment: Containerized Claude Code on Netcup RS 8000

You are running inside a Docker container (`claude-dev`) on Netcup RS 8000.
You are NOT running on WSL2. Do NOT convert paths to Windows URIs.
You run as user `dev` (uid 1001), caps dropped, no-new-privileges enforced.

---

## WHAT YOU CAN DO
- Edit files in `/opt/websites/` and `/opt/apps/` (mounted from host)
- Run `docker` and `docker compose` commands (socket mounted)
- Use `git` with SSH keys (Gitea via `/home/dev/.ssh/gitea_ed25519`)
- Manage secrets via `keepass-write`, `keepass-inject`, `infisical-write`, and `infisical-inject`
- Read/write your own config in `~/.claude/`

## WHAT YOU CANNOT DO
- Access `/root/` or host system files outside mounted volumes
- Run `systemctl`, `ufw`, or other host-level system commands
- Modify Docker daemon config or Traefik config directly
- Read secret values directly — you have write-only + inject access
- For host-level operations, tell the user what to run on the host shell

---

## SAFETY GUIDELINES
**WARN before:** Overwriting files/credentials, deleting data, modifying production configs, destructive git commands, dropping databases, restarting critical services

**CRITICAL — this is a production server with 40+ live services. Extra caution on:**
- `docker compose down` (stops live services)
- Modifying Traefik/Cloudflare config (affects ALL routing)
- Restarting databases (ERPNext Postgres, Discourse, etc.)

---

## VERSION CONTROL
- **Gitea** (`gitea.jeffemmett.com`): PRIMARY — push here FIRST
- **GitHub**: Public mirror, auto-synced from Gitea

### DEV BRANCH WORKFLOW (MANDATORY)
```
main (production) → dev (staging) → feature/*
```
1. **ALWAYS work on `dev` branch** for new features
2. After completing, push to dev and update backlog task
3. **NEVER push directly to main**

---

## SECRETS MANAGEMENT (write-only + inject)

You have write-only access to both KeePass and Infisical. You can create, set,
and inject secrets into deployment commands, but NEVER read or display secret values.

### KeePass — `keepass-write`
KeePass database at `/keepass/Jeff secure passwords.kdbx` (synced via Syncthing).
Master password auto-loaded from Infisical to tmpfs at container startup.

```bash
keepass-write add "Services/MyApp/postgres" -u postgres -g    # Add entry (auto-gen password)
keepass-write mkdir "Services/NewProject"                      # Create group
keepass-write ls "Services/"                                   # List entries (names only)
keepass-write search "postgres"                                # Search by name
keepass-write generate -L 32 -l -u -n -s                      # Generate password (not stored)
keepass-write edit "Services/MyApp/postgres" -u newuser        # Edit entry
```

### KeePass injection — `keepass-inject`
```bash
# Inject password into a command (password never shown)
keepass-inject "Services/MyApp/db" password -- \
  sh -c 'echo "DB_PASSWORD=$KEEPASS_SECRET" >> /opt/apps/myapp/.env'

# Read non-secret attributes directly
keepass-inject "Services/MyApp/db" username
```
Passwords are NEVER printed — only injected via `$KEEPASS_SECRET` env var.

### Infisical — `infisical-write`
```bash
infisical-write set <folder> <key> <value>     # Create/update a secret
infisical-write list [folder]                   # List secret names (or folders)
infisical-write folders                         # List available folders
infisical-write search <term>                   # Search secrets by name
infisical-write all                             # List all secret paths
infisical-write inject <folder> -- <cmd>        # Run cmd with ALL folder secrets as env vars
```

### Infisical single-secret injection — `infisical-inject`
```bash
# Inject single secret into a command
infisical-inject <folder> <key> -- <command>
    # Secret available as $INFISICAL_SECRET env var

# Use custom env var name
infisical-inject <folder> <key> --env-name VAR_NAME -- <command>
    # Secret available as $VAR_NAME instead
```
The value is NEVER printed — only passed via environment variable.

### Workflow for deploying services with secrets
1. Generate password: `keepass-write generate -L 32`
2. Store in KeePass: `keepass-write add "Services/MyApp/db" -u postgres -g`
3. Store in Infisical: `infisical-write set myapp DB_PASSWORD "<generated>"`
4. Reference in docker-compose via entrypoint-wrapper.sh (fetches from Infisical at startup)
5. Use `keepass-inject` or `infisical-inject` to pass secrets to deployment commands

### Rules
- **NEVER** use `secrets` or `infisical-ops` directly (blocked by deny rules)
- **NEVER** use `keepassxc-cli show/export/clip/dump` directly (blocked)
- **NEVER** read `.kdbx` files or `/run/keepass-master`
- **KeePass** = personal passwords | **Infisical** = deployment secrets

---

## INFISICAL POLICY
1. NEVER hardcode secrets in docker-compose.yml
2. Only `INFISICAL_CLIENT_ID` + `INFISICAL_CLIENT_SECRET` in `.env` files
3. All other secrets fetched at container startup via entrypoint-wrapper.sh

---

## QUICK REFERENCE
- **This server**: Netcup RS 8000 G12 Pro | 20 cores, 64GB RAM, 3TB
- **Apps**: `/opt/apps/` | **Websites**: `/opt/websites/`
- **Infisical**: `https://secrets.jeffemmett.com`
- **Backlog**: `backlog.jeffemmett.com`

---

## BACKLOG.MD TASK MANAGEMENT
```bash
backlog search "<description>" --plain          # Check if task exists
backlog task create "Title" -d "..." -p high    # Create task
backlog task edit <id> -s "In Progress"         # Start work
backlog task edit <id> --append-notes "..."     # Add notes
backlog task edit <id> --check-ac 1             # Check acceptance criteria
backlog task edit <id> -s Done --append-notes "Complete"  # Finish
```

**AC GATE (ENFORCED):** Tasks with unchecked ACs are **auto-reverted** to "In Progress" when marked Done. You MUST `--check-ac N` for every AC before setting status to Done. Override: add `<!-- AC_WAIVED -->` to task file.

---

## CONTEXT LOOKUP (loaded on demand)
| Topic | File |
|-------|------|
| API tokens, credentials | `~/.claude/context/credentials.md` |
| Traefik, Cloudflare, deploy | `~/.claude/context/infrastructure.md` |
| Docker services & health | `~/.claude/context/services.md` |
| GPU costs, AI routing | `~/.claude/context/gpu-and-ai.md` |

## SPECIALIZED AGENTS
Agents in `~/.claude/agents/` with memory in `~/.claude/agent-memory/<name>/`:
- **infra-manager** — Docker, Traefik, Cloudflare, system operations
- **security-reviewer** — Hardening compliance, credential hygiene
- **deployment-tracker** — Service status, deployment events, health

---

## TROUBLESHOOTING
**tmux "server exited unexpectedly":** `rm -f /tmp/tmux-$(id -u)/default`
**Container won't start:** `docker compose logs <service>`, verify Infisical secrets accessible
**Traefik 404:** Verify container on `traefik-public` network with correct labels
**525 SSL Error:** DNS CNAME must point to tunnel ID, not server IP
