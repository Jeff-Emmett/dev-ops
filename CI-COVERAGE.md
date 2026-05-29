# CI/CD Coverage Audit

> Snapshot: 2026-05-28. Tracks TASK-044 (unified backlog).
> Re-run via `~/Github/dev-ops/scripts/ci-coverage.sh`.

## Summary

| Bucket | Count |
|---|---|
| Has CI (`.gitea/workflows/*.yml`) | 81 |
| No CI, deployable (Dockerfile or compose present) | 99 |
| No CI, no Docker (skip-eligible) | 128 |
| **Total local repos** | **308** |

Reproducible via `dev-ops/scripts/ci-coverage.sh` (writes a sorted table
to stdout). "Deployable" = repo has either `docker-compose*.yml` or a
`Dockerfile` at the root or one level down. CI templates live in
`dev-ops/ci-templates/` (`node-app`, `python-app`, `static-site`,
`book-build`, `cadcad-app`).

## What "good" looks like

For an active rApp / holon-service / substrate repo, CI should:
1. Run tests on push to `dev` + `main` and PR to `main`.
2. Type-check (TS) or import-check (Py) before tests.
3. On `main`, build + push image + deploy via Compose on Netcup.
4. Where there are cross-repo contracts (canonical hash fixtures, GraphQL
   schemas), a parity-check job that fails on drift.

## High-priority no-CI repos (active ≤14 days)

These are deployed or about-to-be-deployed services that need CI now.

| Repo | Last commit | Template | Notes |
|---|---|---|---|
| **ai-orchestrator** | 10 hours | python-app | Sequence-router + carrier registry; tests exist |
| **rNetwork-online** | 27 hours | node-app | rApp pattern; Next.js |
| **graphene-as-currency** | 3 days | node-app (mixed) | Has scripts/`cadcad-app` would also fit |
| **mycopunk-swag-store** | 11 hours | node-app | Storefront, low test surface |
| **long-now-book-of-time-application** | 12 hours | static-site | Application repo; docs + HTML prototype only |
| **commons-hub-website** | 6 days | node-app | Self-hosted Next.js, already deployed |
| **mycofi-stickers** | 6 days | static-site | Print-on-demand stickers UI |
| **crypto-commons-website-2.0** | 10 days | static-site | Marketing site |
| **katheryn-website** | 11 days | static-site | Single-tenant landing page |
| **logseq-graph** | 2 days | (skip) | Personal knowledge graph; vault, not a deploy target — move to skip bucket |
| **backlog** | 10 hours | (skip) | netcup-unified backlog repo; tasks only, no deploy artefact |
| **configuration** | 3 days | (skip) | Personal dotfiles bundle |
| **jeffsi-meet** | 2 days | docker-compose | Jitsi fork; vendor compose, likely no CI needed |

### Sub-tasks to create

- `TASK-MEDIUM.49` — Add CI to **ai-orchestrator** (python-app template + pytest)
- `TASK-MEDIUM.50` — Add CI to **rNetwork-online** (node-app template + bun test if any)
- `TASK-MEDIUM.51` — Add CI to **graphene-as-currency** (node-app or cadcad-app, decide based on entrypoint)
- `TASK-MEDIUM.52` — Add CI to **commons-hub-website**
- Sticker / landing-page sites batched into one task: `TASK-LOW.x` — Add static-site CI to mycopunk-swag-store, mycofi-stickers, crypto-commons-website-2.0, katheryn-website
- Move **logseq-graph**, **backlog**, **configuration** into the skip bucket explicitly (these are state stores, not deploy targets)

## Medium-priority no-CI repos (active 15–60 days)

Federation + holon-stack tier. Add CI as touch surface returns.

```
rmesh-online            5 weeks   (Next.js rApp; basePath /rmesh)
rmesh-holonserve        5 weeks   (HTTP-over-Reticulum publisher; Python)
rmesh-reticulum         5 weeks   (Reticulum bridge; Python)
rstack                  5 weeks   (Meta-index; node-app)
mesh-browser            5 weeks   (Electron; Reticulum browser)
upload-service          5 weeks   (R2 uploader; node-app)
mandala-mic             5 weeks   (Electron / audio; deferrable)
semantic-search         6 weeks   (Python embeddings API; already deployed)
payment-forge           4 weeks   (Stripe forge; node-app)
image-forge             4 weeks   (Image conversion MCP; node-app)
media-forge             4 weeks   (Media transcode forge; node-app)
doc-forge               4 weeks   (Doc conversion forge; node-app)
morpheus-engine-pool    4 weeks   (Engine pool; python-app)
settlement-rs           4 weeks   (Settlement service; cargo-app — template TBD)
trust-engine-rs         3 weeks   (Trust engine; cargo-app — template TBD)
janus-knn-rs            4 weeks   (KNN sidecar; cargo-app — template TBD)
clip-forge              4 weeks   (Clip extraction; node/python mixed)
cadcad-mcp-server       4 weeks   (cadCAD MCP; python-app)
cadcad-lab              4 weeks   (cadCAD lab; python-app)
meeting-intelligence    3 weeks   (Transcription pipeline; python-app)
token-engineering       3 weeks   (Modelling; cadcad-app)
alife-cadcad-research   3 weeks   (cadCAD model; cadcad-app)
compost-capitalism-website  3 weeks  (static-site)
engineering-design-loop  2 weeks  (Tooling; node-app)
html-in-canvas-demo     2 weeks   (Demo; static-site)
taketh                  2 weeks   (taketh.lol cause site; static-site)
```

Two missing CI-template categories to author:
- **cargo-app** (Rust) — for `settlement-rs`, `trust-engine-rs`, `janus-knn-rs`
- **electron-app** — if `mesh-browser` / `mandala-mic` want CI-built artefacts

## Lower-priority no-CI deployable (>60 days idle)

~50 repos. Most are exploration, archived prototypes, or one-shot
deploys (Aragon, Quartz live, NEARPeer, etc.). Sweep policy:

1. Tag the obvious-archive ones with `archived` topic in Gitea.
2. For the long-tail "might come back": leave un-CI'd. If a touch
   resurrects activity, the high/medium-priority workflow above
   catches them on the next audit.

Full list in `git -C ~/Github log --format=%cr` order, see
`/tmp/repo-noci-bydate.txt` (regenerable via the script below).

## Skip-eligible (128 repos)

Documentation, vaults, ZIP-of-website, vendor source mirrors. Examples:
`Obsidian-Vault`, `JMM-FHE-LLM`, `OSF-Website`, `Jeff's Vault`,
`Myseelia`, `TEC-analysis`, `kindness-fund-website`, `fileverse` (3rd
party), `kiwi-mcp` (3rd party clone), `mapmap`, `web3`, `website`,
`wiki`, `zk-glasses`, etc.

These get no CI by design. Mostly content stores or vendored code.

## Has-CI repos (81)

Includes all `r*-online` rApps that ship via Compose + Traefik (rauctions,
rcal, rcart, rchats, rdata, rfiles-rclone-backend, rforum, rfunds, rmail,
rmaps, rnotes, rsocials, rspace, rstack, rswag, rtube, rvote, rwallet,
rwork), the substrate (encryptid-sdk, holon-service, rspace-registry),
plus marketing sites and personal services. Sample audit (2026-05-28):

- All hit the `localhost:3000/jeffemmett/...` registry.
- Most use the `node-app` template; a handful use `python-app`
  (rauctions has no Python, but books-website etc. use book-build).
- 3 use `static-site`.
- No repo currently uses `cadcad-app` or `book-build` despite the
  templates existing — consider seeding one to validate the template.

Two CI gotchas worth recording (already in memory):

- `actions/checkout` is broken on Gitea 1.21 — every workflow uses a
  raw `git clone http://token:${{ github.token }}@server:3000/...`.
- The runner has capacity 1 (set in `~/gitea/config.yaml` on Netcup) so
  jobs are sequential and won't OOM the shared host.

## Cross-repo parity check (new pattern)

**encryptid-sdk** and **holon-service** now both have a `parity-check`
job that diffs `tests/fixtures/canonical-fixtures.json` byte-for-byte.
Editing either side without regenerating from
`encryptid-sdk/tools/gen-canonical-fixtures.mjs` fails CI in *both*
repos on the next push.

This is the model for future cross-repo contracts:

- TS↔Python protocol fixtures
- GraphQL schema fragments
- iCal X-JMJMJ-* extension wire format

Document each parity link in this file as it goes live.

## Re-running the audit

```bash
bash ~/Github/dev-ops/scripts/ci-coverage.sh > /tmp/ci-cov.out
tail -3 /tmp/ci-cov.out  # summary line
grep "| no-ci-deployable " /tmp/ci-cov.out | sort  # repos missing CI
```

Update this file when:
- A repo flips from no-CI to has-CI (move it up + remove the row).
- A repo is archived (drop from no-CI, add to skip list).
- A new template lands in `ci-templates/`.

## Related

- Templates: `dev-ops/ci-templates/` (node-app.yml, python-app.yml,
  static-site.yml, book-build.yml, cadcad-app.yml)
- Runner config: Netcup `/root/gitea/` (capacity 1, `node:20-bookworm-slim`)
- Registry: `gitea.jeffemmett.com/v2/` (internal: `localhost:3000`)
- Deploy webhook: `/opt/deploy-webhook/webhook.py` (alt path: image-push
  triggers, not git-push)
- Memory notes:
  - `ci-cd.md` — Gitea Actions runner config, gotchas, deployed pipelines
  - `playwright-headless-screenshots.md` — global Playwright for headless UI tests
  - `gitea-oom-crawler.md` — Gitea memory pressure, not CI-related but
    affects runner stability
