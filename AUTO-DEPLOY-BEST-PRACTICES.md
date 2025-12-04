# Auto-Deploy Best Practices

This document outlines the DevOps standards for all deployed websites and applications.

## Architecture Overview

```
Push to Gitea → Webhook fires → Deploy server pulls & rebuilds → Site goes live
```

**Components:**
- **Gitea** (`gitea.jeffemmett.com`): Primary git repository
- **Deploy Webhook** (`deploy.jeffemmett.com`): Receives webhooks, triggers deploys
- **Traefik**: Reverse proxy with automatic service discovery
- **Cloudflare Tunnel**: Secure ingress from internet

## Required Files for Auto-Deploy

Every deployable repository MUST have these files:

### 1. `docker-compose.yml`

```yaml
services:
  <service-name>:
    build: .
    image: <service>-prod:latest
    container_name: <service>-prod
    restart: always
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.<service>.rule=Host(`domain.com`) || Host(`www.domain.com`)"
      - "traefik.http.routers.<service>.entrypoints=web"
      - "traefik.http.services.<service>.loadbalancer.server.port=80"

networks:
  traefik-public:
    external: true
```

**Key points:**
- Service name, image, container must be consistent
- Always join `traefik-public` network
- Use proper Traefik labels for routing

### 2. `Dockerfile`

Standard Next.js/static site example:

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/out /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### 3. `.gitignore`

Must include:
```gitignore
# Claude Code local instructions (symlink)
CLAUDE.md
```

### 4. `.dockerignore`

Must include to prevent build failures:
```dockerignore
# Git
.git
.gitignore

# Development
node_modules
.next
.cache

# Documentation - DO NOT include in builds
README.md
CLAUDE.md
*.md

# IDE
.idea
.vscode
*.swp

# Environment
.env
.env.local
.env*.local
```

**CRITICAL:** `CLAUDE.md` must be in `.dockerignore` because it's often a symlink to a local file that doesn't exist in the build context.

## Webhook Configuration

### 1. Add repo to webhook system

Edit `/opt/deploy-webhook/webhook.py` on netcup:

```python
REPOS = {
    'my-new-site': {
        'path': '/opt/websites/my-new-site',
        'build_cmd': 'docker compose up -d --build'
    },
    # ... other repos
}
```

Then rebuild: `cd /opt/deploy-webhook && docker compose up -d --build`

### 2. Add Gitea webhook

```bash
curl -X POST "https://gitea.jeffemmett.com/api/v1/repos/jeffemmett/<repo>/hooks" \
  -H "Authorization: token <gitea-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "gitea",
    "active": true,
    "events": ["push"],
    "config": {
      "url": "https://deploy.jeffemmett.com/deploy/<repo>",
      "content_type": "json",
      "secret": "gitea-deploy-secret-2025"
    }
  }'
```

## Deploy Flow

1. Developer pushes to Gitea (main branch)
2. Gitea sends webhook to `deploy.jeffemmett.com/deploy/<repo>`
3. Webhook server:
   - Verifies HMAC signature
   - Runs `git pull origin`
   - Runs `docker compose up -d --build`
4. Traefik auto-discovers new container via labels
5. Site is live

## Troubleshooting

### Check deploy logs
```bash
ssh netcup "docker exec deploy-webhook cat /var/log/deploys/<repo>_<timestamp>.log"
```

### Common issues

| Error | Cause | Fix |
|-------|-------|-----|
| `no configuration file provided` | Missing docker-compose.yml | Add docker-compose.yml to repo |
| `ENOENT: no such file, stat '/app/CLAUDE.md'` | CLAUDE.md symlink in build | Add CLAUDE.md to .dockerignore |
| `container name already in use` | Old container from central compose | `docker stop <name> && docker rm <name>` |
| `Unknown repo` | Repo not in webhook.py | Add to REPOS dict and rebuild |

### Verify webhook is configured
```bash
# Check webhook system has the repo
curl -s https://deploy.jeffemmett.com/health | jq '.repos'

# Check Gitea has webhook for repo
curl -s "https://gitea.jeffemmett.com/api/v1/repos/jeffemmett/<repo>/hooks" \
  -H "Authorization: token <token>"
```

## Migration from Central Compose

If a site was previously managed via `/root/websites/all-websites.yml`:

1. Create `docker-compose.yml` in the repo (copy config from central file)
2. Stop old container: `docker stop <name> && docker rm <name>`
3. Deploy from repo: `cd /opt/websites/<repo> && docker compose up -d --build`
4. Remove service from `all-websites.yml`

## Checklist for New Sites

- [ ] Repository has `Dockerfile`
- [ ] Repository has `docker-compose.yml` with Traefik labels
- [ ] Repository has `.gitignore` with `CLAUDE.md`
- [ ] Repository has `.dockerignore` with `CLAUDE.md`
- [ ] Repo added to webhook.py REPOS dict
- [ ] Webhook added to Gitea repo
- [ ] Domain DNS points to Cloudflare tunnel
- [ ] Hostname added to Cloudflare tunnel config (if new domain)
- [ ] Test: push to main and verify site updates

## Current Deployed Sites

All sites in `/opt/websites/` on netcup are auto-deployed via this system.

To audit:
```bash
ssh netcup "for site in /opt/websites/*/; do
  name=\$(basename \$site)
  compose=\$([ -f \${site}docker-compose.yml ] && echo '✅' || echo '❌')
  ignore=\$(grep -q CLAUDE.md \${site}.dockerignore 2>/dev/null && echo '✅' || echo '❌')
  echo \"\$compose \$ignore \$name\"
done"
```
