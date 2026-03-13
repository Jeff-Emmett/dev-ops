---
id: TASK-63
title: 'AT Protocol Integration for rStack — PDS, Identity Bridge & Federated Trust Graph'
status: In Progress
assignee: []
created_date: '2026-03-13 19:40'
labels:
  - atproto
  - identity
  - rnetwork
  - r*stack
  - federation
dependencies: []
references:
  - /opt/apps/atproto-pds/
  - /opt/apps/atproto-bridge/
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extend rStack's trust and identity systems into the federated AT Protocol network. Two main integrations:

1. **Self-hosted PDS + Identity Bridge** — Deploy the official AT Protocol PDS at `pds.ridentity.online` and a Bun/Hono identity bridge service that maps EncryptID `did:key` ↔ AT Protocol `did:web` identities, provisions PDS accounts, and serves DID documents.

2. **Federated Trust Graph** — Custom `online.rnetwork.*` lexicons for trust allocations, delegations, categories, and identity links. Sync pipeline publishes rNetwork trust mutations to AT Protocol repos in real time.

### Completed (2026-03-13)
- PDS docker-compose with entrypoint-wrapper Infisical integration
- Identity Bridge service (Hono + SQLite): `/api/link`, DID document serving, identity lookups
- EncryptID SDK `atproto?` extension on `EncryptIDClaims.eid`
- 4 custom lexicon definitions (`online.rnetwork.trust.{allocation,delegation,category}`, `online.rnetwork.identity.link`)
- Automerge graph-store trust-change event emission
- AT Protocol sync pipeline (Automerge → bridge API → PDS records)
- Trust-scores API extended with `atprotoUris`
- Registry updated with PDS and bridge entries
- Infisical secrets created (`PDS_JWT_SECRET`, `PDS_ADMIN_PASSWORD`, `PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX`)
- Cloudflare DNS already configured (pds.ridentity.online, ridentity.online, *.ridentity.online → tunnel)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 PDS docker-compose.yml with Infisical entrypoint-wrapper
- [x] #2 Identity Bridge service with `/api/link`, DID document routes, SQLite store
- [x] #3 EncryptID SDK `atproto?` field extension
- [x] #4 Custom AT Protocol lexicon definitions (4 lexicons)
- [x] #5 Trust-change event emission from Automerge graph-store
- [x] #6 AT Protocol sync pipeline (atproto-sync.ts)
- [x] #7 Trust-scores API extended with atprotoUris
- [x] #8 Registry updated with new services
- [x] #9 Infisical secrets and Cloudflare DNS configured
- [ ] #10 Start PDS container and verify health endpoint
- [ ] #11 Start bridge container and verify DID document serving
- [ ] #12 Add cloudflared tunnel ingress rules on host (requires host shell access)
- [ ] #13 Rebuild rNetwork-online with sync pipeline
- [ ] #14 End-to-end test: EncryptID link → PDS account → trust sync → AT Protocol record verification
- [ ] #15 Request relay crawling from PDS Admins Discord
<!-- AC:END -->
