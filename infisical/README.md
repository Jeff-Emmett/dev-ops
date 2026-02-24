# Infisical Secret Management Tooling

Central tooling for managing deployment secrets via [Infisical](https://secrets.jeffemmett.com).

## Architecture

```
Container Start → entrypoint.sh → Infisical API → env vars injected → app starts
                                      ↑
                           INFISICAL_CLIENT_ID +
                           INFISICAL_CLIENT_SECRET
                           (only secrets in .env)
```

All deployment secrets live in Infisical. Containers only need two env vars (`INFISICAL_CLIENT_ID`, `INFISICAL_CLIENT_SECRET`) to fetch all their secrets at startup.

## Templates

| Template | Runtime | Use Case |
|----------|---------|----------|
| `entrypoint-node.sh` | Node.js | Custom apps with Node.js in the image |
| `entrypoint-bun.sh` | Bun | Custom apps using Bun runtime |
| `entrypoint-python.sh` | Python 3 | Custom apps with Python in the image |
| `entrypoint-wrapper.sh` | Auto-detect | Third-party images (volume-mounted) |

### Using a template in a custom app

1. Copy the appropriate template to your repo as `entrypoint.sh`
2. In your `Dockerfile`:
   ```dockerfile
   COPY entrypoint.sh /entrypoint.sh
   RUN chmod +x /entrypoint.sh
   ENTRYPOINT ["/entrypoint.sh"]
   CMD ["node", "server.js"]
   ```
3. In your `docker-compose.yml`:
   ```yaml
   environment:
     - INFISICAL_CLIENT_ID=${INFISICAL_CLIENT_ID}
     - INFISICAL_CLIENT_SECRET=${INFISICAL_CLIENT_SECRET}
     - INFISICAL_PROJECT_SLUG=my-service
   ```

### Using the wrapper for third-party images

For images you can't modify (Ghost, n8n, Mattermost, etc.):

1. Volume-mount the shared wrapper from Netcup:
   ```yaml
   services:
     myapp:
       image: ghost:5
       volumes:
         - /opt/infisical/entrypoint-wrapper.sh:/infisical-entrypoint.sh:ro
       entrypoint: ["/infisical-entrypoint.sh"]
       command: ["node", "current/index.js"]  # original CMD
       environment:
         - INFISICAL_CLIENT_ID=${INFISICAL_CLIENT_ID}
         - INFISICAL_CLIENT_SECRET=${INFISICAL_CLIENT_SECRET}
         - INFISICAL_PROJECT_SLUG=my-ghost
   ```

2. Find the original CMD with: `docker inspect <image> --format '{{json .Config.Cmd}}'`

## Scripts

### `create-project.sh <slug>`
Creates an Infisical project + machine identity + universal auth credentials.
Outputs the `INFISICAL_CLIENT_ID` and `INFISICAL_CLIENT_SECRET` to put in `.env`.

```bash
export INFISICAL_TOKEN="<org-admin-token>"
./scripts/create-project.sh my-service
```

### `migrate-env.sh <env-file> <project-slug> [environment]`
Reads a `.env` file and pushes all secrets to an Infisical project.
Skips `INFISICAL_*` vars and comments.

```bash
export INFISICAL_TOKEN="<admin-token>"
./scripts/migrate-env.sh /opt/websites/myapp/.env my-service prod
```

### `audit-secrets.sh [ssh-host]`
Scans all compose files on Netcup for:
- Hardcoded secrets (passwords, tokens, keys)
- `.env` files with non-Infisical secrets
- Services missing Infisical integration

```bash
./scripts/audit-secrets.sh netcup
```

### `verify-injection.sh [ssh-host] [filter]`
Checks container logs to confirm secret injection is working.

```bash
./scripts/verify-injection.sh netcup          # all containers
./scripts/verify-injection.sh netcup ghost    # only ghost containers
```

## Migration Workflow

For each service:

1. **Create project**: `./scripts/create-project.sh <slug>`
2. **Push secrets**: `./scripts/migrate-env.sh <env-file> <slug>`
3. **Wire entrypoint**: Copy template or mount wrapper
4. **Deploy**: `docker compose up -d --build`
5. **Verify**: `./scripts/verify-injection.sh netcup <name>`
6. **Cleanup**: Back up `.env` as `.env.pre-infisical`, strip to only `INFISICAL_*` vars

## Inventory

See `inventory.yaml` for the full list of services and their migration status.
