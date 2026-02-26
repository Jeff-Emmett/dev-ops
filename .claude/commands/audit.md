---
description: Audit secrets and Infisical configuration across projects
argument-hint: [project-name|all]
allowed-tools: Read, Glob, Grep, Bash, Task
---

# Secret Audit

Audit for hardcoded secrets and verify Infisical integration. Use the Task tool with `model: "sonnet"` for thorough analysis.

## Scope

If a project name is given, audit that project. If "all" or no argument, scan all projects under `/home/jeffe/Github/`.

## Checks

1. **Hardcoded secrets scan** (delegate to Task agent with model: "haiku" for speed):
   - Grep for patterns: `password=`, `secret=`, `api_key=`, `token=`, base64-encoded strings
   - Check docker-compose.yml files for inline secrets
   - Check .env files that shouldn't exist in repos
   - Ignore `.git/`, `node_modules/`, vendored directories

2. **Infisical integration verification**:
   - Does the project have INFISICAL_CLIENT_ID/SECRET references?
   - Is entrypoint.sh using the Infisical pattern?
   - Are secrets being fetched at runtime (not baked into images)?

3. **Read credentials context** from `~/.claude/context/credentials.md` for Infisical details.

4. **Report findings** in a table:
   | Project | Hardcoded Secrets | Infisical Integrated | Issues |
   |---------|-------------------|---------------------|--------|

5. **Suggest remediation** for any issues found, referencing Infisical migration scripts in `~/Github/dev-ops/infisical/scripts/`.
