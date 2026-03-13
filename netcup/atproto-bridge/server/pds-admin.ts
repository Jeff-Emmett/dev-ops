/**
 * PDS account provisioning via com.atproto.server.createAccount
 */

import { AtpAgent } from "@atproto/api";

const PDS_URL = process.env.PDS_URL || "https://pds.ridentity.online";
const PDS_ADMIN_PASSWORD = process.env.PDS_ADMIN_PASSWORD || "";

let agent: AtpAgent | null = null;

function getAgent(): AtpAgent {
  if (!agent) {
    agent = new AtpAgent({ service: PDS_URL });
  }
  return agent;
}

export interface CreateAccountResult {
  did: string;
  handle: string;
  accessJwt: string;
  refreshJwt: string;
}

/**
 * Create a new account on the PDS via the admin invite flow.
 * Returns the PDS-assigned DID (did:plc:...) and session tokens.
 */
export async function createPDSAccount(
  handle: string,
  email: string,
  password: string,
): Promise<CreateAccountResult> {
  const pdsAgent = getAgent();

  // Create invite code via admin endpoint
  const inviteRes = await pdsAgent.api.com.atproto.server.createInviteCode(
    { useCount: 1 },
    {
      headers: {
        Authorization: `Basic ${btoa(`admin:${PDS_ADMIN_PASSWORD}`)}`,
      },
      encoding: "application/json",
    },
  );

  const inviteCode = inviteRes.data.code;

  // Create account using the invite code
  const accountRes = await pdsAgent.api.com.atproto.server.createAccount({
    handle,
    email,
    password,
    inviteCode,
  });

  return {
    did: accountRes.data.did,
    handle: accountRes.data.handle,
    accessJwt: accountRes.data.accessJwt,
    refreshJwt: accountRes.data.refreshJwt,
  };
}

/**
 * Create an authenticated agent session for an existing PDS account.
 */
export async function loginPDSAccount(
  identifier: string,
  password: string,
): Promise<AtpAgent> {
  const pdsAgent = new AtpAgent({ service: PDS_URL });
  await pdsAgent.login({ identifier, password });
  return pdsAgent;
}
