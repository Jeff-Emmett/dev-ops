---
id: task-8
title: Audit and Dockerize all website repos
status: To Do
assignee: []
created_date: '2025-12-04 06:26'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Ensure all website repositories have proper Docker configurations for consistent deployment.

Check each repo for:
- Dockerfile (optimized, multi-stage build)
- docker-compose.yml with Traefik labels
- Health check endpoint
- Proper .dockerignore

Repos to audit:
- All *-website directories in /home/jeffe/Github/
- Any web apps that should be containerized

Standardize on the deployment pattern:
- Traefik labels for auto-discovery
- Join traefik-public network
- Health checks for monitoring
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All website repos have Dockerfile
- [ ] #2 All website repos have docker-compose.yml with Traefik labels
- [ ] #3 All containers have health checks defined
- [ ] #4 Deployment documentation updated
<!-- AC:END -->
