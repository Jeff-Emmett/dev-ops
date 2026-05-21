---
id: TASK-LOW.6
title: Deploy Langfuse LLM Observability Platform
status: To Do
assignee: []
created_date: '2026-04-12 22:17'
labels: []
dependencies: []
parent_task_id: TASK-LOW
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Self-host Langfuse v3 on Netcup for LLM trace observability, eval scoring, and prompt management. Triggered when rSpace multi-user AI usage scales beyond what cloud free tier (50k obs/month) can handle. Integrate with LiteLLM (native Langfuse callback), wire secrets through Infisical, Traefik labels for langfuse.jeffemmett.com. Note: ~25 GB RAM footprint (ClickHouse 8GB, PG 4GB, Web 4GB, Worker 4GB, Redis 1.5GB, MinIO 4GB). Consider Langfuse Cloud free tier as interim step to validate value before self-hosting.
<!-- SECTION:DESCRIPTION:END -->
