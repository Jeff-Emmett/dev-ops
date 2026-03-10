## Dev-Ops Repository

Central infrastructure and deployment tooling for all services on Netcup RS 8000.

## Key Directories

| Path | Purpose |
|------|---------|
| `infisical/` | Secret management: templates, scripts, inventory |
| `infisical/templates/` | Entrypoint templates (node, bun, python, wrapper) |
| `infisical/scripts/` | `create-project.sh`, `migrate-env.sh`, `audit-secrets.sh`, `verify-injection.sh` |
| `infisical/inventory.yaml` | Full service migration status |
| `netcup/` | Server configs: Traefik, systemd, cron, Ansible |
| `netcup/ansible/` | Ansible playbooks for server provisioning |
| `netcup/traefik/` | Traefik reverse proxy configuration |
| `scripts/` | Utility scripts (backlog-surfacer.py) |
| `agents/` | Agent configurations (backlog-surfacer) |

## Infisical Integration Pattern

Containers need only `INFISICAL_CLIENT_ID` + `INFISICAL_CLIENT_SECRET` in `.env`.
All other secrets fetched at startup via entrypoint script.

- **Custom apps**: Copy template from `infisical/templates/` into Dockerfile
- **Third-party images**: Volume-mount `/opt/infisical/entrypoint-wrapper.sh` from Netcup
- **New service**: `./infisical/scripts/create-project.sh <slug>` then `migrate-env.sh`

## Common Commands

```bash
# Create new Infisical project
export INFISICAL_TOKEN="<org-admin-token>"
./infisical/scripts/create-project.sh my-service

# Push existing .env to Infisical
./infisical/scripts/migrate-env.sh /path/to/.env my-service prod

# Audit for hardcoded secrets on server
./infisical/scripts/audit-secrets.sh netcup

# Verify secret injection is working
./infisical/scripts/verify-injection.sh netcup [filter]
```

## Deployment

All services deploy to Netcup via Docker Compose + Traefik auto-discovery.
SSH: `ssh netcup` | Apps at `/opt/apps/` on server | Traefik network: `traefik-public`.
