---
id: TASK-50
title: Switch PentAGI LLM backend from Claude to local model
status: To Do
assignee: []
created_date: '2026-02-25 09:29'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Anthropic Claude refuses to execute penetration testing tasks against real infrastructure, even with explicit authorization. This is a fundamental limitation for an offensive security tool.

Symptoms:
- Flows 1 & 3 failed: Claude returned refusal text as Docker image name (literal "i cant help with this request..." as image name)
- PentAGI reflector circuit breaker triggered after 4 retries
- Flows 2, 4, 5, 6 stalled: containers running but no task decomposition

Fix:
- Change PROVIDER from "anthropic" to "ollama" in PentAGI .env
- Use a local model that will cooperate (Mixtral, Llama 3, Qwen)
- Alternatively, consider using a different API-based model
- Test with a simple scan to verify the new model generates valid subtasks

Location: /opt/apps/pentagi/ on Netcup
<!-- SECTION:DESCRIPTION:END -->
