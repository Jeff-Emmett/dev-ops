---
id: TASK-49
title: Fix internal service CORS misconfigurations
status: To Do
assignee: []
created_date: '2026-02-25 09:29'
labels: []
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PentAGI scans identified CORS misconfigurations on internal services. While these are not externally reachable (blocked by DOCKER-USER iptables chain), they should be hardened as defense-in-depth.

Affected services:
1. Transmission (port 9091) - Access-Control-Allow-Origin: * (wide open CORS)
2. Port 3010 Express API - CORS vulnerability flagged
3. Port 8222 RESTinio DHT node - Access-Control-Allow-Origin: * + info disclosure (exposes internal IP and network stats)
4. Port 8005 Semantic Search API - Swagger/OpenAPI docs publicly exposed

All are shielded by DOCKER-USER DROP rule on eth0, so external exploitation is blocked. Fix for defense-in-depth.
<!-- SECTION:DESCRIPTION:END -->
