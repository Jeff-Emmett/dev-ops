/**
 * AT Protocol Sync Pipeline
 *
 * Listens for trust-change events from graph-store,
 * diffs against last-published state, and writes
 * online.rnetwork.trust.* records to the PDS.
 */

import { AtpAgent } from "@atproto/api";
import type { TrustAllocation, TrustDelegation, ExpertiseCategory } from "../lib/trust-types";

const BRIDGE_API_URL = process.env.ATPROTO_BRIDGE_URL || "http://atproto-bridge:3001";
const PDS_URL = process.env.ATPROTO_PDS_URL || "";

// Track last-published state to avoid duplicate writes
const publishedAllocations = new Map<string, string>(); // allocationId → hash
const publishedDelegations = new Map<string, string>();

interface ResolvedIdentity {
  encryptidDID: string;
  atprotoDID: string;
  handle: string;
  pdsAccountDID: string;
}

/**
 * Resolve a graph nodeId (e.g. "person-{twentyId}") to an AT Protocol DID
 * via the bridge API. Returns null if node has no linked identity.
 */
async function resolveNodeToDID(nodeId: string, nodeLabel: string, workspaceSlug: string): Promise<{
  did: string;
  linked: boolean;
}> {
  try {
    // Try looking up by EncryptID DID — the nodeId in the graph might map to one
    const res = await fetch(`${BRIDGE_API_URL}/api/identity/by-encryptid/${encodeURIComponent(nodeId)}`);
    if (res.ok) {
      const identity: ResolvedIdentity = await res.json();
      return { did: identity.atprotoDID, linked: true };
    }
  } catch {
    // Bridge not available or no mapping
  }

  // Fallback: use placeholder label
  return {
    did: `label:${nodeLabel} (${workspaceSlug})`,
    linked: false,
  };
}

/**
 * Compute a simple hash of an allocation for change detection
 */
function hashAllocation(a: TrustAllocation): string {
  return `${a.targetNodeId}:${a.categoryId}:${a.amount}:${a.updatedAt}`;
}

function hashDelegation(d: TrustDelegation): string {
  return `${d.delegateNodeId}:${d.categoryId}:${d.percentage}:${d.updatedAt}`;
}

export interface TrustChangeEvent {
  type: "allocation" | "delegation";
  workspaceSlug: string;
  allocation?: TrustAllocation;
  delegation?: TrustDelegation;
  categories: Record<string, ExpertiseCategory>;
  nodes: Record<string, { label: string }>;
}

/**
 * Process a trust change event and publish to AT Protocol
 */
export async function processTrustChange(event: TrustChangeEvent): Promise<void> {
  if (!PDS_URL) return; // AT Protocol sync disabled

  try {
    if (event.type === "allocation" && event.allocation) {
      await syncAllocation(event.allocation, event.categories, event.nodes, event.workspaceSlug);
    } else if (event.type === "delegation" && event.delegation) {
      await syncDelegation(event.delegation, event.categories, event.nodes, event.workspaceSlug);
    }
  } catch (err) {
    console.error("[ATProto Sync] Failed to process trust change:", err);
  }
}

async function syncAllocation(
  allocation: TrustAllocation,
  categories: Record<string, ExpertiseCategory>,
  nodes: Record<string, { label: string }>,
  workspaceSlug: string,
): Promise<void> {
  const hash = hashAllocation(allocation);
  if (publishedAllocations.get(allocation.id) === hash) return;

  const targetNode = nodes[allocation.targetNodeId];
  if (!targetNode) return;

  const resolved = await resolveNodeToDID(
    allocation.targetNodeId,
    targetNode.label,
    workspaceSlug,
  );

  const category = categories[allocation.categoryId];

  const record = {
    $type: "online.rnetwork.trust.allocation",
    targetDID: resolved.did,
    targetLinked: resolved.linked,
    categoryId: allocation.categoryId,
    categoryName: category?.name || "Unknown",
    amount: allocation.amount,
    workspaceSlug,
    createdAt: allocation.updatedAt || new Date().toISOString(),
  };

  // Look up allocator's AT Protocol session
  const allocatorIdentity = await resolveAllocatorSession(allocation.allocatorDID);
  if (!allocatorIdentity) {
    console.log(`[ATProto Sync] Allocator ${allocation.allocatorDID} has no AT Protocol session, skipping`);
    return;
  }

  try {
    await allocatorIdentity.agent.api.com.atproto.repo.putRecord({
      repo: allocatorIdentity.agent.session!.did,
      collection: "online.rnetwork.trust.allocation",
      rkey: allocation.id,
      record,
    });

    publishedAllocations.set(allocation.id, hash);
    console.log(`[ATProto Sync] Published allocation ${allocation.id}`);
  } catch (err) {
    console.error(`[ATProto Sync] Failed to publish allocation ${allocation.id}:`, err);
  }
}

async function syncDelegation(
  delegation: TrustDelegation,
  categories: Record<string, ExpertiseCategory>,
  nodes: Record<string, { label: string }>,
  workspaceSlug: string,
): Promise<void> {
  const hash = hashDelegation(delegation);
  if (publishedDelegations.get(delegation.id) === hash) return;

  const delegateNode = nodes[delegation.delegateNodeId];
  if (!delegateNode) return;

  const resolved = await resolveNodeToDID(
    delegation.delegateNodeId,
    delegateNode.label,
    workspaceSlug,
  );

  const category = categories[delegation.categoryId];

  const record = {
    $type: "online.rnetwork.trust.delegation",
    delegateDID: resolved.did,
    delegateLinked: resolved.linked,
    categoryId: delegation.categoryId,
    categoryName: category?.name || "Unknown",
    percentage: delegation.percentage,
    workspaceSlug,
    createdAt: delegation.updatedAt || new Date().toISOString(),
  };

  const delegatorIdentity = await resolveAllocatorSession(delegation.delegatorDID);
  if (!delegatorIdentity) return;

  try {
    await delegatorIdentity.agent.api.com.atproto.repo.putRecord({
      repo: delegatorIdentity.agent.session!.did,
      collection: "online.rnetwork.trust.delegation",
      rkey: delegation.id,
      record,
    });

    publishedDelegations.set(delegation.id, hash);
    console.log(`[ATProto Sync] Published delegation ${delegation.id}`);
  } catch (err) {
    console.error(`[ATProto Sync] Failed to publish delegation ${delegation.id}:`, err);
  }
}

// Cache of authenticated AT Protocol agents per allocator DID
const agentCache = new Map<string, { agent: AtpAgent; expiresAt: number }>();

async function resolveAllocatorSession(allocatorDID: string): Promise<{ agent: AtpAgent } | null> {
  const cached = agentCache.get(allocatorDID);
  if (cached && cached.expiresAt > Date.now()) {
    return { agent: cached.agent };
  }

  try {
    // Look up the allocator's AT Protocol identity via bridge
    const res = await fetch(`${BRIDGE_API_URL}/api/identity/by-encryptid/${encodeURIComponent(allocatorDID)}`);
    if (!res.ok) return null;

    const identity: ResolvedIdentity = await res.json();

    // For now, the sync pipeline uses the PDS service auth
    // In production, each user would maintain their own session
    const agent = new AtpAgent({ service: PDS_URL });

    // Cache for 10 minutes
    agentCache.set(allocatorDID, { agent, expiresAt: Date.now() + 600_000 });
    return { agent };
  } catch {
    return null;
  }
}

/**
 * Get the AT Protocol URI for a published trust record (if any)
 */
export function getAtprotoUri(recordId: string, type: "allocation" | "delegation"): string | null {
  const map = type === "allocation" ? publishedAllocations : publishedDelegations;
  if (map.has(recordId)) {
    return `at://online.rnetwork.trust.${type}/${recordId}`;
  }
  return null;
}
