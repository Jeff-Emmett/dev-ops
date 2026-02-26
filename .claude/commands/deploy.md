---
description: Pre-deployment checklist and deploy a service to Netcup
argument-hint: <service-name>
allowed-tools: Read, Glob, Grep, Bash, Task
---

# Deploy Service

Run a pre-deployment checklist then deploy to Netcup. Use the Task tool with `model: "sonnet"` for the validation sub-agent.

## Steps

1. **Identify the service** from the argument. Find its docker-compose.yml and related config.

2. **Pre-flight checks** (delegate to a Task agent with model: "haiku"):
   - docker-compose.yml is valid YAML
   - No hardcoded secrets (check for API keys, passwords, tokens in compose file)
   - Infisical integration present (INFISICAL_CLIENT_ID, INFISICAL_CLIENT_SECRET)
   - Traefik labels present and correctly formatted
   - Network `traefik-public` is referenced
   - Health check defined

3. **Read infrastructure context** from `~/.claude/context/infrastructure.md` for deployment procedures.

4. **Show the deployment plan** to the user:
   - What will be deployed
   - Which server (Netcup)
   - What Docker commands will run
   - Any DNS/Cloudflare changes needed

5. **Wait for user confirmation** before executing any SSH commands.

6. **Deploy** using the standard procedure:
   ```
   ssh netcup-full "cd /opt/websites/<project> && docker compose pull && docker compose up -d --build"
   ```

7. **Verify** the service is running:
   ```
   ssh netcup "docker ps | grep <service>"
   ```

8. **Update backlog** if there's a related task.
