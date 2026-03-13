/**
 * Generates did:web DID documents with dual verification methods
 * (AT Protocol + EncryptID)
 */

const PDS_HOSTNAME = process.env.PDS_HOSTNAME || "pds.ridentity.online";
const BRIDGE_HOSTNAME = process.env.BRIDGE_HOSTNAME || "ridentity.online";

export interface DIDDocumentOptions {
  username: string;
  encryptidDID: string;
  pdsAccountDID?: string;
}

/**
 * Generate a per-user DID document for did:web:ridentity.online:users:{username}
 */
export function generateUserDIDDocument(opts: DIDDocumentOptions) {
  const didWeb = `did:web:${BRIDGE_HOSTNAME}:users:${opts.username}`;

  return {
    "@context": [
      "https://www.w3.org/ns/did/v1",
      "https://w3id.org/security/multikey/v1",
      "https://w3id.org/security/suites/secp256k1-2019/v1",
    ],
    id: didWeb,
    alsoKnownAs: [
      `at://${opts.username}.${BRIDGE_HOSTNAME}`,
      opts.encryptidDID,
    ],
    verificationMethod: [
      {
        id: `${didWeb}#atproto`,
        type: "Multikey",
        controller: didWeb,
        publicKeyMultibase: "", // Populated when PDS account is created
      },
      {
        id: `${didWeb}#encryptid`,
        type: "Multikey",
        controller: didWeb,
        publicKeyMultibase: extractKeyFromDID(opts.encryptidDID),
      },
    ],
    service: [
      {
        id: "#atproto_pds",
        type: "AtprotoPersonalDataServer",
        serviceEndpoint: `https://${PDS_HOSTNAME}`,
      },
      {
        id: "#encryptid",
        type: "EncryptIDService",
        serviceEndpoint: `https://${BRIDGE_HOSTNAME}`,
      },
    ],
  };
}

/**
 * Generate the root DID document for did:web:ridentity.online
 */
export function generateRootDIDDocument() {
  const didWeb = `did:web:${BRIDGE_HOSTNAME}`;

  return {
    "@context": [
      "https://www.w3.org/ns/did/v1",
      "https://w3id.org/security/multikey/v1",
    ],
    id: didWeb,
    service: [
      {
        id: "#atproto_pds",
        type: "AtprotoPersonalDataServer",
        serviceEndpoint: `https://${PDS_HOSTNAME}`,
      },
      {
        id: "#identity_bridge",
        type: "IdentityBridgeService",
        serviceEndpoint: `https://${BRIDGE_HOSTNAME}/api`,
      },
    ],
  };
}

/**
 * Extract the multibase key portion from a did:key
 * did:key:z6Mk... → z6Mk...
 */
function extractKeyFromDID(didKey: string): string {
  if (didKey.startsWith("did:key:")) {
    return didKey.slice("did:key:".length);
  }
  return didKey;
}
