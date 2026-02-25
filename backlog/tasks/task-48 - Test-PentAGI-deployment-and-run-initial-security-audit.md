---
id: TASK-48
title: Test PentAGI deployment and run initial security audit
status: Done
assignee: []
created_date: '2026-02-25 06:44'
updated_date: '2026-02-25 09:29'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PentAGI deployed to /opt/apps/pentagi/ on Netcup RS 8000.
Access: https://100.64.0.2:8444 (Headscale mesh only)
LLM: Anthropic Claude via API key
Embeddings: Ollama nomic-embed-text (local)
Search: DuckDuckGo (free)

Testing checklist:
1. Create first user account via web UI
2. Run basic port scan against a test target
3. Run web app pentest against gitea.jeffemmett.com
4. Run web app pentest against canvas website
5. Run web app pentest against deploy webhook endpoint
6. Test memory persistence across sessions
7. Review findings and create remediation tasks
8. Consider adding Traefik dashboard (:8888) to scan targets
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 First user account created
- [ ] #2 Basic scan completed against test target
- [ ] #3 Gitea pentest completed
- [ ] #4 Canvas website pentest completed
- [ ] #5 Deploy webhook pentest completed
- [ ] #6 Findings reviewed and remediation tasks created
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PentAGI deployed and initial security audit completed (2026-02-25).

Flows created: 6 (web app scan, infra scan, Docker/Traefik audit, web misconfig)
Results: Partial - Claude LLM refused some pentesting subtasks.

Key findings identified and acted on:
- Redis 6379 exposed without auth → FIXED (container removed + UFW deny)
- Ollama 11434 exposed without auth → FIXED (UFW deny)
- Traefik default cert info disclosure → FIXED (replaced with CN=localhost)
- 10+ sensitive services unprotected → FIXED (Cloudflare Access added)
- p2pwiki-ai 8420, erowid-bot 8421 exposed → FIXED (UFW deny)
- DOCKER-USER iptables chain confirmed blocking most Docker ports externally

Remaining items backlogged as separate tasks.
<!-- SECTION:NOTES:END -->
