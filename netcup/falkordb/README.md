# FalkorDB on Netcup

Internal-only graph database (Redis-protocol, Cypher query language) for AI
agent memory and KOI knowledge graphs.

- Image: `falkordb/falkordb:latest` (Server Side Public License v1)
- Bind: `127.0.0.1:6380` on Netcup (Redis port shifted from 6379 to avoid
  collision with any other Redis instance)
- Internal access: container name `falkordb` on the `traefik-public` Docker
  network, port `6379` (container's internal port)
- No Traefik route, no Cloudflare tunnel — Redis protocol, not HTTP

## Deploy

```bash
# On Netcup
sudo mkdir -p /opt/apps/falkordb
cd /opt/apps/falkordb

# Sync compose
scp ~/Github/dev-ops/netcup/falkordb/docker-compose.yml netcup-full:/opt/apps/falkordb/

# Set password (or migrate to Infisical entrypoint pattern)
sudo cp .env.example .env
sudo chmod 600 .env
# edit .env, set FALKORDB_PASSWORD to a long random string

sudo docker compose up -d falkordb
sudo docker compose logs falkordb | tail -20
sudo docker exec falkordb redis-cli -a "$(grep FALKORDB_PASSWORD .env | cut -d= -f2)" ping
# expect: PONG
```

## Access from WSL2 dev

```bash
# Quick tunnel
ssh -L 6380:127.0.0.1:6380 netcup
# Then point falkormem MCP at localhost:6380
```

For permanent access from WSL2 (without an open SSH session), wire FalkorDB to
the Tailscale interface and bind on the Tailscale IP — see follow-up task.

## Optional: browser UI

```bash
# On Netcup
sudo docker compose --profile debug up -d falkordb-browser
# Then on WSL2: ssh -L 3001:127.0.0.1:3001 netcup
# Open http://localhost:3001
```

## Connection from other containers on Netcup

Other services on `traefik-public` reach FalkorDB at `falkordb:6379` (the
container's internal port, not the published 6380). Example for an MCP server
container or agent:

```yaml
environment:
  FALKORDB_HOST: falkordb
  FALKORDB_PORT: 6379
  FALKORDB_PASSWORD: ${FALKORDB_PASSWORD}
```

## Backup

`falkordb-data` Docker volume is auto-discovered by the Netcup backup system
(`/opt/backup-system/`, restic→R2→Hetzner). RDB snapshots are written via the
`--save 60 1 --save 300 100` flags configured in the compose file.

## Use cases

- **falkormem MCP** — Claude Code's persistent knowledge graph (replaces the
  JSONL `memory` MCP). See `~/.claude/mcp-servers/falkormem/`.
- **KOI substrate** — TASK-MEDIUM.12 canonical BlockScience port. Requires
  swapping `koi-net`'s neo4j driver for the FalkorDB client; pattern
  documented separately.
- **Future: rspace knowledge graph** — content/author/tag relationships when
  that need materializes.
