---
id: TASK-84
title: Migrate KOI bundle store from in-memory Map to FalkorDB
status: In Progress
assignee: []
created_date: '2026-05-09 06:28'
updated_date: '2026-05-09 14:32'
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
- [x] #1 KoiBundleStore interface preserved (existing call sites in server/koi-routes.ts unchanged)
- [x] #2 FalkorDB-backed implementation behind a flag (KOI_STORE=falkordb vs KOI_STORE=memory)
- [x] #3 koi-routes.test.ts passes against both implementations
- [x] #4 Bundle dedupe logic preserved (re-upserting same RID is idempotent)
- [x] #5 Event poll preserves total order across restarts (FalkorDB persistence carries the log)
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Shipped on branch `feat/koi-falkordb-store` in rspace-online (commit 96982c96).

**What changed:**
- `shared/koi/store.ts` — extracted `IKoiBundleStore` async interface + shared `filterRidsByTypes` helper. Existing `KoiBundleStore` made async-conforming.
- `shared/koi/store.falkordb.ts` — new `FalkorDBKoiBundleStore` impl. Schema: `(:Bundle {rid, manifest_json, contents_json, seq})`, `(:Event {seq, rid, event_type, manifest_json?, contents_json?})`, `(:Counter {name:'event_seq', value})`. Total event order via monotonic counter so `pollEvents` preserves ordering across restarts.
- `shared/koi/store.factory.ts` — `createKoiStore()` reads `KOI_STORE` env (`memory` default | `falkordb`).
- `shared/koi/store.shared.test.ts` — parameterized conformance suite. Both store impls run identical assertions.
- `shared/koi/store.falkordb.test.ts` — FalkorDB-specific tests including persistence-across-fresh-instance. Skipped when `FALKORDB_HOST` unset (CI-friendly).
- `server/koi-routes.ts` — uses `createKoiStore()` factory; awaits all store ops.
- `server/koi-routes.test.ts` — await additions for now-async store calls.

**Schema choice rationale:** Manifest + contents stored as canonicalized JSON strings rather than decomposed into property graphs. Preserves the hash invariant trivially (canonical-JSON byte equivalence on round-trip) and avoids forcing schema-mapping for every payload type (RTM cell, attestation, future bundle types).

**Test results:**
- In-memory store conformance: 13/13 pass
- FalkorDB store conformance: 14/14 pass against Netcup tailnet target (37s — real network)
- koi-routes (in-memory default): 8/8 pass
- koi-routes (KOI_STORE=falkordb against tailnet): 8/8 pass

**Connection from rspace-online to FalkorDB on Netcup:**
- Production (container on Netcup): `FALKORDB_HOST=falkordb` `FALKORDB_PORT=6379` (docker network)
- WSL2 dev: `FALKORDB_HOST=100.64.0.2` `FALKORDB_PORT=6380` (Tailscale)
- Password from `/opt/apps/falkordb/.env` on Netcup or `~/.claude/mcp-servers/falkormem/.netcup-falkor-pwd` on WSL2

**Production rollout:** branch is feat-only, not merged. To enable on the deployed rspace-online container, set `KOI_STORE=falkordb` + `FALKORDB_*` env vars on the docker-compose for the rspace-online service. Default behaviour (no env) stays in-memory — zero-risk merge.
<!-- SECTION:FINAL_SUMMARY:END -->
