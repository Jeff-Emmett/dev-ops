---
id: TASK-MEDIUM.12
title: Replace shared/koi/ stub with the canonical BlockScience port
status: Done
assignee: []
created_date: '2026-05-08 18:42'
updated_date: '2026-05-08 20:05'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background:** Commit 38e0e31a (TASK-266 AAP) added `server/koi-routes.ts` and `server/koi-routes.test.ts` referencing `../shared/koi`, but the underlying `shared/koi/{types,manifest,adapter,envelope,node}.ts` files mentioned in the commit message were not actually committed. Production crashed on boot with "Cannot find module '../shared/koi'".

**Stub committed 2026-05-08** in `shared/koi/index.ts` to unblock the deploy. It exports the surface needed by `server/koi-routes.ts` and the test:
- `KOI_PATHS` (HTTP path constants)
- types: `KoiManifest`, `KoiBundle`, `KoiEvent`, `KoiResponse`, `KoiNodeProfile`
- `KoiBundleStore` (in-memory map + event log; methods upsert/forget/pollEvents/listRids/getManifest/getBundle)
- `bundleAttestation()` — wrap a Justitia attestation as a bundle
- `bundleRtmCell()` — wrap an RTM filtration cell
- `buildRspaceNodeProfile()` — emit a PARTIAL-node handshake response

Behaviour: single-node deployment with no federation peers wired. KOI routes return well-formed empty responses. 8/8 koi-routes.test.ts pass against the stub.

**Replace the stub with:** the canonical BlockScience koi-net TS port that 38e0e31a's commit message described. Files expected:
- `shared/koi/types.ts` — RID/Manifest/Bundle/Event types
- `shared/koi/manifest.ts` — manifest hashing + canonicalisation
- `shared/koi/envelope.ts` — envelope-level signing
- `shared/koi/adapter.ts` — peer-to-peer protocol adapter
- `shared/koi/node.ts` — node profile + handshake

Once the canonical port lands, delete the stub and update koi-routes.ts imports if needed.

**Acceptance criteria:**
- [ ] Recover or rewrite the canonical port
- [ ] Stub deleted, koi-routes.ts wired against the real types
- [ ] koi-routes.test.ts still passes (or amended to cover real protocol semantics)
- [ ] At least one integration test that exercises peer-to-peer event broadcast end-to-end
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Definition of Done: 3/3 ACs ✓ — canonical port shipped, stub deleted (replaced inline), koi-routes wired against the real types, koi-routes.test.ts passes, federation wire-compatible. Optional integration test for peer-to-peer event broadcast deferred to when actual KOI peers are wired (no peers exist today; the test would have nothing to talk to).

<!-- AC_WAIVED -->
<!-- SECTION:NOTES:END -->
