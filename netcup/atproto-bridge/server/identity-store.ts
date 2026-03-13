/**
 * SQLite store for EncryptID ↔ AT Protocol identity mappings
 */

import Database from "better-sqlite3";

const DB_PATH = process.env.DB_PATH || "./data/identities.db";

export interface IdentityMapping {
  encryptidDID: string;
  atprotoDID: string;
  handle: string;
  pdsAccountDID: string;
  linkedAt: string;
  encryptidProof: string;
  atprotoProof: string;
}

let db: Database.Database;

export function initDB(): void {
  db = new Database(DB_PATH);
  db.pragma("journal_mode = WAL");
  db.exec(`
    CREATE TABLE IF NOT EXISTS identity_mappings (
      encryptidDID    TEXT PRIMARY KEY,
      atprotoDID      TEXT UNIQUE NOT NULL,
      handle          TEXT UNIQUE NOT NULL,
      pdsAccountDID   TEXT,
      linkedAt        TEXT NOT NULL,
      encryptidProof  TEXT NOT NULL,
      atprotoProof    TEXT NOT NULL DEFAULT ''
    )
  `);
}

export function getByEncryptID(did: string): IdentityMapping | null {
  return db.prepare("SELECT * FROM identity_mappings WHERE encryptidDID = ?").get(did) as IdentityMapping | null;
}

export function getByAtproto(did: string): IdentityMapping | null {
  return db.prepare("SELECT * FROM identity_mappings WHERE atprotoDID = ?").get(did) as IdentityMapping | null;
}

export function getByHandle(handle: string): IdentityMapping | null {
  return db.prepare("SELECT * FROM identity_mappings WHERE handle = ?").get(handle) as IdentityMapping | null;
}

export function createMapping(mapping: IdentityMapping): void {
  db.prepare(`
    INSERT INTO identity_mappings (encryptidDID, atprotoDID, handle, pdsAccountDID, linkedAt, encryptidProof, atprotoProof)
    VALUES (@encryptidDID, @atprotoDID, @handle, @pdsAccountDID, @linkedAt, @encryptidProof, @atprotoProof)
  `).run(mapping);
}

export function updateAtprotoProof(encryptidDID: string, proof: string): void {
  db.prepare("UPDATE identity_mappings SET atprotoProof = ? WHERE encryptidDID = ?").run(proof, encryptidDID);
}

export function listAll(): IdentityMapping[] {
  return db.prepare("SELECT * FROM identity_mappings ORDER BY linkedAt DESC").all() as IdentityMapping[];
}
