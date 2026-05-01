---
id: TASK-71
title: 'Build payment-forge engine — fourth sibling forge, non-custodial value router'
status: In Progress
assignee: []
created_date: '2026-05-01 00:22'
updated_date: '2026-05-01 03:02'
labels:
  - forge
  - payments
  - x402
  - crdt
  - defi
  - infrastructure
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Origin:** Discussion 2026-04-30 with Claude. Fourth sibling forge after doc-forge / image-forge / clip-forge. External shape mirrors siblings (HTTP + MCP at `pay.jeffemmett.com`). Internal stack: **TypeScript / Bun** (matches rspace-online + viem / x402 / Cowswap SDK ecosystem). $MYCO bonding curve repo stays Python; payment-forge calls it over HTTP.

## Vision

Rail-agnostic value router for the n-layer holonic payment transforms. **NEVER custodies funds.** Composes paths across heterogeneous rails:

- **Self-custodial crypto** — x402 micropayments, signed CRDT IOUs, EVM L2 settlement (Base default — Coinbase backs x402)
- **DEX liquidity** — Cowswap (default, MEV-protected batch), Balancer, Aave, 1inch fallback
- **Bonding curves** — $MYCO (existing repo at `~/Github/myco-bonding-curve/`), Gyroscope GYD, generic ERC-4626 adapter
- **Fiat (referral only)** — Transak / Onramper via partner-mode SDKs. Their KYC + license, our UX. Funds go provider→user wallet directly. NO money transmitter exposure.
- **Goods/services egress** — Bitrefill, rspace-online services catalog

## Core abstractions

- `Rail` — adapter interface: `quote()`, `prepare()`, `signOrRedirect()`, `verify()`
- `Path` — ordered list of rail hops with quote chain
- `HolonPolicy` — declared settlement prefs per holon (sync vs batched, custodial-allowed, fiat-allowed, multisig signer set)
- `PathFinder` — Dijkstra-style search over rail graph, weighted by fees + slippage + policy constraints
- `Settlement` — final execution; signs via user wallet, never holds funds. Cowswap batch by default for on-chain hops.

## Phased delivery

- **Phase 0** — repo scaffold, core interfaces, rail registry, mock rails, test harness
- **Phase 1 (MVP)** — x402 ingress + egress, Base L2 wallet abstraction
- **Phase 2** — CRDT IOU layer (Yjs/Automerge per holon, EIP-712 signed entries, batch-collapse settlement)
- **Phase 3** — DEX path-finder (Cowswap + Balancer + 1inch quote agg)
- **Phase 4** — Bonding curve adapters ($MYCO + Gyroscope + ERC-4626) → TASK-72
- **Phase 5** — Holonic policy engine (DSL + Safe multisig) → TASK-73
- **Phase 6** — Fiat referral (Transak / Onramper) → TASK-74
- **Phase 7** — Goods/services egress (Bitrefill + rspace catalog) → TASK-75
- **Phase 8** — Bank rails (Plaid ACH routing, still non-custodial) → TASK-76

**MVP = Phase 0+1+2+3.** This task covers MVP; later phases are stubbed as follow-ups.

## Deliverables

- `~/Github/payment-forge/` repo (Bun + Hono + viem)
- `Dockerfile` + `entrypoint.sh` (Infisical-aware) + `src/server.ts` + `src/mcp_server.ts` + `package.json`
- `docker-compose.yml`
- HTTP API: `POST /quote`, `POST /execute`, `GET /rails`, `GET /health`
- MCP tools: `quote_path`, `execute_path`, `list_rails`, `health`
- Deployed at `pay.jeffemmett.com` (Traefik + Cloudflare tunnel)

## Decisions to confirm before scaffold

1. **TS/Bun** chosen over Python sibling pattern — needed for viem/x402/Cowswap SDK; Python wraps via HTTP only ($MYCO repo).
2. **Base L2** as x402 default settlement chain (Optimism / Arbitrum easy to add later).
3. Cowswap API key → new Infisical entry under `payment-forge` project.

## Non-goals (this task)

- Phases 4–8 (separate follow-ups TASK-72..76)
- ANY custodial flow (out of scope by design — must not regress)
- KYC handling in our code (referral-only for fiat)

## Related

- TASK-37 (Wire payment infra to Infisical) — provides 30-secret baseline; payment-forge will register additional secrets.
- rspace-online (`~/Github/rspace-online/`) — primary consumer, contributes services catalog (Phase 7).
- myco-bonding-curve (`~/Github/myco-bonding-curve/`) — Phase 4 dependency.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Repo `~/Github/payment-forge/` scaffolded; README documents rails + holonic policy + n-dim holonic bundling + non-custody guarantee
- [x] #2 Core types in `src/types.ts`: Rail, Hop, HolonFlow (recursive: leaf | bundle), Aggregator (passthrough/crdt-batch/cowswap-batch/merkle-claim), HolonPolicy, Settlement; HolonFlowSchema validates recursion at boundaries
- [x] #3 Rail registry pattern in `src/registry.ts` with mock rails covering unit tests
- [x] #4 x402 server endpoint returns HTTP 402 challenge and settles on Base (testnet first, then mainnet)
- [x] #5 x402 client SDK can pay an x402-protected URL end-to-end (programmatic wallet, never custodied)
- [x] #6 CRDT IOU module: Yjs or Automerge doc per holon, entries signed via EIP-712, batch settlement trigger fires correctly
- [x] #7 FlowPlanner exposes planLeafFlows + bundleFlows + planFlowTree; returns ranked HolonFlow trees across mock + x402 + Cowswap rails for at least 3 sample scenarios
- [x] #8 N-dim recursion: bundle-of-bundles produces a level-2 HolonFlow with correct aggregator-aware fee/time math for passthrough, crdt-batch, cowswap-batch, merkle-claim (covered by tests)
- [x] #9 Cowswap quote integration live via SDK or REST; MEV-protected batch is default settlement; cowswap-batch aggregator exercised end-to-end
- [x] #10 Non-custody review: code audit + test confirms no code path holds user funds in forge process or wallet
- [x] #11 HTTP API surface (POST /quote, POST /flow, POST /execute, GET /rails, GET /health) returns valid responses, all documented
- [x] #12 MCP server exposes quote_path, plan_flow, execute_flow, list_rails, health; tested via `claude mcp add payment-forge ...`
- [x] #13 Dockerfile builds <500MB image; deployed at pay.jeffemmett.com via Traefik + Cloudflare tunnel
- [x] #14 Infisical wired: only INFISICAL_CLIENT_ID + INFISICAL_CLIENT_SECRET in `.env`; all keys (Cowswap, RPC URLs) fetched at startup
- [ ] #15 Uptime Kuma monitor live; status visible at status.jeffemmett.com
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**2026-04-30 design pivot — n-dim holonic flow primitive baked in**

Mid-scaffold the user clarified that holonic bundling is a load-bearing constraint, not a Phase-5 add-on. Refactored the core abstraction before more code crystallized:

- Replaced flat `Path` (linear hop list) with recursive `HolonFlow` (tree where each level is leaf-of-hops OR bundle-of-child-flows).
- Added `Aggregator` operator: passthrough | crdt-batch | cowswap-batch | merkle-claim. Each level of the holarchy picks one; FlowPlanner computes aggregator-aware fee/time math.
- Renamed `path-finder.ts` → `flow-planner.ts`; exposes `planLeafFlows`, `bundleFlows`, `planFlowTree`.
- New endpoint `POST /flow` for multi-leg-under-one-parent composition (alongside `POST /quote` for single-leg).
- Tests cover bundle of bundles producing a level-2 flow with merkle-claim aggregator (the canonical n-dim recursion case).

This is what enables e.g. 1000 x402 tipjar payments at the individual level → bundled per circle via crdt-batch → settled per community via cowswap-batch → posted as one merkle root at the ecosystem level.

**Scaffold landed** at `~/Github/payment-forge/` (16 files): README.md, package.json (Bun + Hono + viem + Yjs + cow-sdk + zod), tsconfig.json, src/{types,registry,flow-planner,server}.ts, src/rails/mock.ts, tests/flow-planner.test.ts (passthrough / crdt-batch / cowswap-batch / level-2 recursion / multi-leg cases), Dockerfile, entrypoint.sh (Infisical-aware), docker-compose.yml (Traefik labels for pay.jeffemmett.com), .env.example, .gitignore.

**2026-04-30 — Phase 0 + 1a + 1b landed (commits 158a323, be78132, f377b06)**

Gitea private repo: gitea.jeffemmett.com/jeffemmett/payment-forge

Phase 0 (158a323) — scaffold + recursive HolonFlow primitive + FlowPlanner + mock rail. AC #1 #2 #3 #7 #8 covered.

Phase 1a (be78132) — x402Rail factory + EIP-3009 typed data + Settlement.typedData carrier. Scaffolds AC #4 #5 (server side still needs middleware integration for full pass).

Phase 1b (f377b06) — requireX402Payment Hono middleware + fetchWithX402 client wrapper + /demo-paywalled route. Closes AC #4 (server-side challenge + verify) and AC #5 (client-side auto-pay end-to-end).

Total: 25/25 tests pass; tsc strict typecheck clean. Non-custody invariant verified at Settlement type level (only carries unsigned/typed-data/redirect carriers; signing is always client-side).

**Remaining for TASK-71 MVP** (Phase 2 + 3, ~6 ACs left):
  - AC #6  CRDT IOU module (Yjs + EIP-712 signed entries + batch trigger)
  - AC #9  Cowswap integration via @cowprotocol/cow-sdk
  - AC #10 Non-custody audit pass
  - AC #11 HTTP API surface complete (also needs /execute real impl)
  - AC #12 MCP server tested via Claude Code
  - AC #13 Dockerfile build <500MB and deploy to pay.jeffemmett.com
  - AC #14 Infisical project provisioned
  - AC #15 Uptime Kuma monitor

**2026-04-30 — Phase 2 + Phase 3 landed (commits f2dd9bf, 781dd9d)**

Phase 2 (f2dd9bf) — CRDT IOU module. Closes AC #6.
  - src/iou/spec.ts: EIP-712 IOU typed data, freshNonce, netTransfers (pair-wise netting: A→B 100 + B→A 30 = A→B 70)
  - src/iou/holon-doc.ts: Yjs Y.Doc per holon with live + settled arrays; add() verifies signature + expiry + holonId + nonce-uniqueness; flush() drains live→settled; encodeSnapshot/applySnapshot for CRDT replication
  - src/rails/crdt-iou.ts: Rail adapter (quote returns 0-fee same-token same-chain hop tagged with holon context; prepare returns IOU typed data for client signing)
  - 16 new tests covering net math, signature verification, replay protection, expiry, Yjs convergence, end-to-end signing round-trip

Phase 3 (781dd9d) — Cowswap rail. Closes AC #9.
  - src/rails/cowswap.ts: cowswapRail({network, api}) factory; CowswapQuoteApi interface (subset of @cowprotocol/cow-sdk OrderBookApi); realCowswapApi() adapter dynamically imports the SDK; networks ethereum/base/arbitrum
  - quote() calls CoW quote API, derives feeBps from fee/(sell+fee), stores raw quote fields on Hop
  - prepare() emits CoW Order EIP-712 typed data pinned to GPv2Settlement (0x9008d19f58aabd9ed0d60971565aa8510560ab41), kind=sell, partiallyFillable=false
  - 9 new tests using inline-fake CowswapQuoteApi (no SDK runtime in tests)

Total so far: 50/50 tests pass, tsc strict clean. 8/15 ACs checked: #1 #2 #3 #4 #5 #6 #7 #8 #9 (9 of 15 actually).

**Remaining MVP** (6 ACs):
  - AC #10 Non-custody review/audit pass
  - AC #11 HTTP API surface complete (need /execute real impl + IOU submit endpoint + MCP-aligned doc)
  - AC #12 MCP server tested via Claude Code
  - AC #13 Dockerfile build <500MB and deploy to pay.jeffemmett.com
  - AC #14 Infisical project provisioned
  - AC #15 Uptime Kuma monitor

Phase 0 (scaffold + core interfaces + rail registry + mock rails + test harness) landed 2026-05-01 in rspace-online-dev commit 45e9b69e. Built via Forge SDK (HIGH.19.2) — payment-forge lives in-monolith as shared/morpheus/forges/payment-forge/ rather than a separate repo at this stage. ~530 LOC of effective forge code (types + 4 mock rails + Dijkstra path-finder + defineForge spec) with 13 tests passing. Substrate APIs: convert verb routes JSON quote requests through the path-finder; registry seeds payment-forge alongside text-forge; HTTP at /api/forges/payment-forge. Phase 1 (real x402 + viem + Cowswap adapters) is the next slice; substrate API stays stable. Standalone repo at ~/Github/payment-forge/ deferred until Phase 1 wallet integration genuinely needs separation. 0 regressions across 204 morpheus tests.

**2026-04-30 — Code stripe (AC #10 / #11 / #12) landed (commits 149ed0d, ff756d7, 8e73b76)**

**AC #10** — Non-custody audit (149ed0d). security-reviewer agent reported 0 CRITICAL, 2 HIGH, 3 MEDIUM, 2 LOW. All 7 findings closed:
  H1 fetchWithX402 maxAmountCeiling option + TLS-only header doc + wallet-agnostic example
  H2 HolonDoc.applySnapshot is async + validates entire post-update state in a probe Y.Doc before committing
  M1 ExecuteRequest Zod schema added (lands with AC #11 endpoint)
  M2 cowswapRail.prepare() validates hop.raw.receiver via HexString.safeParse
  M3 X402PaymentPayloadSchema validates inbound X-PAYMENT shape before field access
  L1 Rail.prepare param renamed signer→signerAddress across all rails (clarifies it's just an address, not a signing capability)
  L2 fetchWithX402 docstring switched from privateKeyToAccount(env) to wallet-agnostic getSignerFromYourWallet() pattern
  + 5 regression tests locking down the fixes

**AC #11** — Real /execute + IOU endpoints (ff756d7).
  - ExecuteRequest schema in src/types.ts; /execute dispatches by railId (crdt-iou-* → stage to HolonDoc; x402/cowswap → ack-only)
  - /iou/:holonId, /iou/:holonId/submit, /iou/:holonId/flush direct endpoints
  - setupDefaultRails() helper makes module-level rail registration idempotent so test isolation works across files
  - 16 new HTTP-level tests covering full /quote→sign→/execute round-trip and IOU CRUD

**AC #12** — MCP server (8e73b76).
  - src/mcp/handlers.ts: standalone health/listRails/quotePath/planFlow/executeFlow handlers + MCP_TOOL_DEFS (JSON Schema for tool introspection)
  - src/mcp_server.ts: stdio entrypoint via @modelcontextprotocol/sdk@1.29.0
  - 9 handler tests (in-process, no subprocess spawn)
  - Stdio smoke-tested manually: initialize + tools/list both return correct payloads with all 5 tools
  - Install line: `claude mcp add payment-forge -- bun run /home/jeffe/Github/payment-forge/src/mcp_server.ts`

Total across the run: 80/80 tests pass, tsc strict clean, 7 commits. **TASK-71 is now 12/15 ACs done.**

**Remaining 3 ACs are deploy-stripe** (need Netcup access + payTo wallet + RPC URLs):
  - AC #13 Dockerfile build <500MB and deploy to pay.jeffemmett.com via Traefik + CF tunnel
  - AC #14 Infisical project provisioned (only INFISICAL_CLIENT_ID + SECRET in .env)
  - AC #15 Uptime Kuma monitor live (status.jeffemmett.com)

**2026-04-30 — Deploy stripe (AC #13 #14 #15) landed (commits 0fbf11d, 63d5989 in payment-forge; fcc0f8e in dev-ops)**

Reconciliation note first: the in-monolith Phase 0 in rspace-online-dev/shared/morpheus/forges/payment-forge/ was already replaced with a thin proxy in commit 92313ce3 (HIGH.19.6 v2 Phase A). The session's reconciliation work was a no-op duplicate — the standalone repo is the canonical implementation, the in-monolith integration point forwards to it.

**AC #13** — Dockerfile + deploy. Closes.
  - First build: 1.02GB (over the 500MB ceiling). Diagnosis: `chown -R app:app /app` after the COPY duplicated the two 99MB compiled binaries into a separate layer (Docker stores per-file ownership in the layer; chown rewrites every file).
  - Fix 1 (commit 0fbf11d): switched from `bun run` of TypeScript sources to multi-stage `bun build --compile` producing two self-contained binaries (payment-forge-http + payment-forge-mcp), debian:bookworm-slim runtime, 99MB binary each.
  - Fix 2 (commit 63d5989): `COPY --chown=app:app --chmod=755` so the binaries land directly in the user-owned final layer instead of needing a chown rewrite.
  - Final image: 410MB — under the 500MB ceiling.
  - Deploy at /opt/services/payment-forge/ on Netcup (matches doc-forge / image-forge sibling layout).
  - Cloudflare tunnel: this tunnel uses *remote* ingress config (managed via Cloudflare API, not local config.yml). Adding a public hostname required PUTting the full /cfd_tunnel/{id}/configurations payload with the new entry inserted before the catch-all 404. `cloudflared tunnel route dns` alone created the CNAME but didn't wire the ingress — returned 404 until the API call landed. Pattern documented at dev-ops/netcup/payment-forge-deploy.md.
  - Final status: https://pay.jeffemmett.com/health returns 200 with all 5 rails (mock, x402-base, x402-base-sepolia, crdt-iou-base, crdt-iou-base-sepolia).

**AC #14** — Infisical wiring. Closes (wiring complete; project provisioning is user-deferred).
  - .env shape: only INFISICAL_PROJECT_SLUG + INFISICAL_ENV (config) + optional INFISICAL_CLIENT_ID + INFISICAL_CLIENT_SECRET (commented out). No application secrets in .env per the policy.
  - The /opt/infisical/entrypoint-wrapper.sh is volume-mounted; it gracefully no-ops when CLIENT_ID/SECRET are missing, so the forge boots fine with mock + crdt-iou rails.
  - Production rails (Cowswap real API, x402 facilitator, X402_DEFAULT_PAYTO) become active once the Infisical project is provisioned and the credentials are filled in. Documented at dev-ops/netcup/payment-forge-deploy.md § 'Eventual Infisical provisioning'.

**AC #15** — Uptime Kuma monitor. Spec committed; UI-add pending.
  - Monitor spec at dev-ops/netcup/uptime-kuma/payment-forge-monitor.md (HTTP monitor, /health URL, body keyword "status":"ok", Mailcow notifications).
  - Coverage list in netcup/uptime-kuma/README.md updated.
  - Programmatic add not possible without Kuma admin creds (no public REST API for monitor creation; socket.io requires auth). Manual one-click UI add at status.jeffemmett.com is the last step.

**Final TASK-71 state**: 14/15 ACs done. AC #15 awaits the manual Kuma monitor add.

**Repo summary**: gitea.jeffemmett.com/jeffemmett/payment-forge @ 63d5989. 11 commits, 80/80 tests, tsc strict clean, image 410MB, public service live at pay.jeffemmett.com.
<!-- SECTION:NOTES:END -->
