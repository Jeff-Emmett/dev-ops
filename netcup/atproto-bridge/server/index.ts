/**
 * AT Protocol Identity Bridge — Hono server
 *
 * Maps EncryptID did:key ↔ AT Protocol did:web
 * Serves DID documents and provisions PDS accounts
 */

import { Hono } from "hono";
import { cors } from "hono/cors";
import { initDB, getByEncryptID, getByAtproto, getByHandle, createMapping } from "./identity-store";
import { generateUserDIDDocument, generateRootDIDDocument } from "./did-document";
import { createPDSAccount } from "./pds-admin";
import { verifyEncryptIDToken, extractToken } from "@encryptid/sdk/server";
import type { EncryptIDClaims } from "@encryptid/sdk";

const BRIDGE_HOSTNAME = process.env.BRIDGE_HOSTNAME || "ridentity.online";

// Initialize database
initDB();

const app = new Hono();

app.use("*", cors());

// ============================================================================
// DID Documents
// ============================================================================

/** Root DID document: GET /.well-known/did.json */
app.get("/.well-known/did.json", (c) => {
  return c.json(generateRootDIDDocument());
});

/** Per-user DID document: GET /users/:username/did.json */
app.get("/users/:username/did.json", (c) => {
  const { username } = c.req.param();
  const handle = `${username}.${BRIDGE_HOSTNAME}`;

  const mapping = getByHandle(handle);
  if (!mapping) {
    return c.json({ error: "User not found" }, 404);
  }

  const doc = generateUserDIDDocument({
    username,
    encryptidDID: mapping.encryptidDID,
    pdsAccountDID: mapping.pdsAccountDID,
  });

  return c.json(doc);
});

// ============================================================================
// Identity API
// ============================================================================

/**
 * POST /api/link — Link EncryptID to AT Protocol identity
 * Requires EncryptID JWT. Creates did:web mapping and provisions PDS account.
 *
 * Body: { username: string, email: string, proof: string }
 */
app.post("/api/link", async (c) => {
  const token = extractToken(c.req.raw.headers);
  if (!token) {
    return c.json({ error: "Authentication required" }, 401);
  }

  let claims: EncryptIDClaims;
  try {
    claims = await verifyEncryptIDToken(token);
  } catch {
    return c.json({ error: "Invalid token" }, 401);
  }

  const encryptidDID = claims.did;
  if (!encryptidDID) {
    return c.json({ error: "Token missing DID" }, 400);
  }

  // Check if already linked
  const existing = getByEncryptID(encryptidDID);
  if (existing) {
    return c.json({
      error: "Already linked",
      mapping: {
        encryptidDID: existing.encryptidDID,
        atprotoDID: existing.atprotoDID,
        handle: existing.handle,
      },
    }, 409);
  }

  const body = await c.req.json<{ username: string; email: string; proof: string }>();
  const { username, email, proof } = body;

  if (!username || !email || !proof) {
    return c.json({ error: "Missing required fields: username, email, proof" }, 400);
  }

  // Validate username format
  if (!/^[a-z0-9][a-z0-9-]{0,30}[a-z0-9]$/.test(username)) {
    return c.json({ error: "Invalid username format (lowercase alphanumeric + hyphens, 2-32 chars)" }, 400);
  }

  const handle = `${username}.${BRIDGE_HOSTNAME}`;
  const atprotoDID = `did:web:${BRIDGE_HOSTNAME}:users:${username}`;

  // Check handle availability
  if (getByHandle(handle)) {
    return c.json({ error: "Handle already taken" }, 409);
  }

  // Provision PDS account
  let pdsAccountDID = "";
  try {
    // Generate a random password for the PDS account (user authenticates via EncryptID)
    const pdsPassword = crypto.randomUUID() + crypto.randomUUID();
    const pdsResult = await createPDSAccount(handle, email, pdsPassword);
    pdsAccountDID = pdsResult.did;
  } catch (err: any) {
    console.error("[Bridge] PDS account creation failed:", err);
    return c.json({ error: "PDS account provisioning failed", detail: err.message }, 502);
  }

  // Store the mapping
  const mapping = {
    encryptidDID,
    atprotoDID,
    handle,
    pdsAccountDID,
    linkedAt: new Date().toISOString(),
    encryptidProof: proof,
    atprotoProof: "",
  };

  try {
    createMapping(mapping);
  } catch (err: any) {
    console.error("[Bridge] Failed to store mapping:", err);
    return c.json({ error: "Failed to store identity mapping" }, 500);
  }

  return c.json({
    encryptidDID,
    atprotoDID,
    handle,
    pdsAccountDID,
    pdsUrl: `https://${process.env.PDS_HOSTNAME || "pds.ridentity.online"}`,
  }, 201);
});

/** GET /api/identity/:did — Lookup mapping by any DID type */
app.get("/api/identity/:did", (c) => {
  const did = c.req.param("did");

  let mapping = getByAtproto(did) || getByEncryptID(did);
  if (!mapping) {
    return c.json({ error: "Identity not found" }, 404);
  }

  return c.json({
    encryptidDID: mapping.encryptidDID,
    atprotoDID: mapping.atprotoDID,
    handle: mapping.handle,
    pdsAccountDID: mapping.pdsAccountDID,
    linkedAt: mapping.linkedAt,
  });
});

/** GET /api/identity/by-encryptid/:didKey — Reverse lookup by EncryptID */
app.get("/api/identity/by-encryptid/:didKey", (c) => {
  const didKey = c.req.param("didKey");

  const mapping = getByEncryptID(didKey);
  if (!mapping) {
    return c.json({ error: "Identity not found" }, 404);
  }

  return c.json({
    encryptidDID: mapping.encryptidDID,
    atprotoDID: mapping.atprotoDID,
    handle: mapping.handle,
    pdsAccountDID: mapping.pdsAccountDID,
    linkedAt: mapping.linkedAt,
  });
});

// ============================================================================
// Health
// ============================================================================

app.get("/health", (c) => c.json({ ok: true, service: "atproto-bridge" }));

// ============================================================================
// Start
// ============================================================================

const PORT = Number(process.env.PORT) || 3001;

export default {
  port: PORT,
  fetch: app.fetch,
};

console.log(`AT Protocol Identity Bridge running on http://localhost:${PORT}`);
