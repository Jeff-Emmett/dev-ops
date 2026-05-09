---
id: TASK-84
title: Migrate KOI bundle store from in-memory Map to FalkorDB
status: To Do
assignee: []
created_date: '2026-05-09 06:28'
updated_date: '2026-05-09 06:29'
labels:
  - koi
  - falkordb
  - rspace-online
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background:** TASK-MEDIUM.12 shipped the canonical BlockScience koi-net TS port with an in-memory `KoiBundleStore` (Map + event log). Single-node behaviour. FalkorDB is now deployed (see `dev-ops/netcup/falkordb/`) — a Cypher-queryable graph DB on Redis, internal-only on Netcup. This task migrates the in-memory store to FalkorDB so KOI state is persistent, queryable, and ready for federation.

**Why FalkorDB and not Neo4j:**
- BlockScience's reference koi-net (Python) uses Neo4j, but our port is TypeScript and has no driver dependency yet.
- FalkorDB is Cypher-compatible (most queries port verbatim), Redis-protocol (lighter than Neo4j JVM), and already deployed on Netcup.
- Trade-off: FalkorDB has its own client, NOT bolt-protocol — driver code is FalkorDB-specific (`@falkordb/falkordb`), not a generic graph DB driver.

**Schema sketch:**
```cypher
(:KoiBundle {rid, manifest_hash, ts, type, payload})
(:KoiManifest {hash, canonical_json})
(:KoiNode {rid, profile_json})
(:KoiBundle)-[:HAS_MANIFEST]->(:KoiManifest)
(:KoiNode)-[:OWNS]->(:KoiBundle)
(:KoiNode)-[:PEER {trust_level}]->(:KoiNode)
```

**Connection from rspace-online container on Netcup:**
- `FALKORDB_HOST=falkordb` (container name on `traefik-public` network)
- `FALKORDB_PORT=6379`
- `FALKORDB_PASSWORD` from Infisical (or shared `.env` file at `/opt/apps/falkordb/.env`)

**Acceptance criteria:**
- [ ] `KoiBundleStore` interface preserved (existing call sites in `server/koi-routes.ts` unchanged)
- [ ] FalkorDB-backed implementation behind a flag (`KOI_STORE=falkordb` vs `KOI_STORE=memory`)
- [ ] `koi-routes.test.ts` passes against both implementations
- [ ] Bundle dedupe logic preserved (re-upserting same RID is idempotent)
- [ ] Event poll preserves total order across restarts (FalkorDB persistence carries the log)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 KoiBundleStore interface preserved (existing call sites in server/koi-routes.ts unchanged)
- [ ] #2 FalkorDB-backed implementation behind a flag (KOI_STORE=falkordb vs KOI_STORE=memory)
- [ ] #3 koi-routes.test.ts passes against both implementations
- [ ] #4 Bundle dedupe logic preserved (re-upserting same RID is idempotent)
- [ ] #5 Event poll preserves total order across restarts (FalkorDB persistence carries the log)
<!-- AC:END -->
