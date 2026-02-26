---
description: Fast infrastructure validation using Haiku for cost efficiency
argument-hint: <check-type> (dns|containers|services|compose|all)
allowed-tools: Read, Glob, Grep, Bash, Task
---

# Quick Check

Run fast, cheap infrastructure validations. Delegate ALL checks to Task agents with `model: "haiku"` to minimize credit usage.

## Check Types

### dns <domain>
Verify DNS resolution and Cloudflare proxy status:
- `dig +short <domain>`
- Confirm CNAME points to Cloudflare tunnel
- Check for 525 SSL errors (missing DNS config)

### containers
Check Docker container health on Netcup:
- `ssh netcup "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"`
- Flag any containers that are restarting or unhealthy

### services
Verify key services are responding:
- Gitea, Infisical, Mailcow, Syncthing, Traefik dashboard
- Simple HTTP status code checks

### compose <path>
Validate a docker-compose.yml:
- Valid YAML syntax
- Required labels present
- No hardcoded secrets
- Networks correctly configured

### all
Run all checks above sequentially.

## Important
- Use `model: "haiku"` for ALL Task delegations — this command is designed for speed and cost efficiency
- Keep output concise — pass/fail with details only on failures
- Total cost target: <$0.01 per full check
