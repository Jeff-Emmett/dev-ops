# Modifications to Existing Services

## Files Modified (in /opt/apps/)

### encryptid-sdk/src/types/index.ts
Added optional `atproto?` field to `EncryptIDClaims.eid`:
```typescript
atproto?: {
  did: string;      // did:web:ridentity.online:users:...
  handle: string;   // username.ridentity.online
  pdsUrl: string;   // https://pds.ridentity.online
};
```

### rNetwork-online/server/graph-store.ts
- Added `EventEmitter` import and `graphEvents` export
- Added `emitTrustChanges()` function that fires `trust-change` events on Automerge patches touching trust data

### rNetwork-online/server/index.ts
- Imported `graphEvents`, `processTrustChange`, `getAtprotoUri` from sync modules
- Added conditional AT Protocol sync worker init (enabled when `ATPROTO_PDS_URL` is set)
- Extended `/graph/api/trust-scores` response to include `atprotoUris` for published records

### rNetwork-online/server/atproto-sync.ts (new file)
Sync pipeline: listens for trust-change events, resolves DIDs via bridge API, writes `online.rnetwork.trust.*` records to PDS.

### rNetwork-online/.env
Added `ATPROTO_PDS_URL` and `ATPROTO_BRIDGE_URL` vars.

### rspace-registry/apps.json
Added `ridentity-pds` and `ridentity-bridge` entries.

## Infisical Secrets Created
- `atproto-pds/PDS_JWT_SECRET`
- `atproto-pds/PDS_ADMIN_PASSWORD`
- `atproto-pds/PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX`
- `atproto-bridge/PDS_ADMIN_PASSWORD`

## Cloudflare DNS (already configured)
- `pds.ridentity.online` → tunnel CNAME (proxied)
- `ridentity.online` → tunnel CNAME (proxied)
- `*.ridentity.online` → tunnel CNAME (not proxied, for handle resolution)
