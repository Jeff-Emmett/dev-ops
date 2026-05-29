/**
 * Linear webhook signing-secret rotator.
 *
 * Linear's GraphQL `webhookUpdate(input: { id, resourceTypes, ... })`
 * does NOT accept a signing secret — Linear generates it. The only way
 * to rotate is to delete + recreate the webhook, capturing the new
 * `secret` field from the create response.
 *
 * Auth: LINEAR_API_KEY from Infisical (the operator's personal API key,
 * scope=write).
 */
import { infisicalGet } from './_infisical';
import type { Rotator } from './_types';

const GQL = 'https://api.linear.app/graphql';

interface WebhookCreatePayload {
	data?: {
		webhookCreate?: {
			success?: boolean;
			webhook?: { id: string; secret?: string; url: string };
		};
		webhookDelete?: { success?: boolean };
		webhooks?: { nodes: Array<{ id: string; url: string; resourceTypes: string[] }> };
	};
	errors?: unknown[];
}

async function gql(query: string, variables: Record<string, unknown>, apiKey: string): Promise<WebhookCreatePayload> {
	const res = await fetch(GQL, {
		method: 'POST',
		headers: { 'content-type': 'application/json', authorization: apiKey },
		body: JSON.stringify({ query, variables }),
	});
	if (!res.ok) throw new Error(`linear HTTP ${res.status}`);
	return await res.json() as WebhookCreatePayload;
}

export const linearRotator: Rotator = async ({ config }) => {
	const apiKey = await infisicalGet('LINEAR_API_KEY');
	if (!apiKey) return { ok: false, error: 'LINEAR_API_KEY missing in Infisical' };
	const pattern = (config.rspaceWebhookUrlPattern as string) || 'rspace.online/api/bridges/linear/webhook';

	const list = await gql(`{ webhooks { nodes { id url resourceTypes } } }`, {}, apiKey);
	const match = list.data?.webhooks?.nodes?.find((w) => w.url.includes(pattern));
	if (!match) return { ok: false, error: 'no Linear webhook matches the rspace URL pattern' };

	const created = await gql(
		`mutation($input: WebhookCreateInput!) { webhookCreate(input: $input) { success webhook { id secret url } } }`,
		{ input: { url: match.url, resourceTypes: match.resourceTypes, enabled: true } },
		apiKey,
	);
	const newWebhook = created.data?.webhookCreate?.webhook;
	if (!newWebhook?.secret) return { ok: false, error: 'Linear webhookCreate returned no secret' };

	const deleted = await gql(`mutation($id: String!) { webhookDelete(id: $id) { success } }`, { id: match.id }, apiKey);
	if (!deleted.data?.webhookDelete?.success) {
		return { ok: false, error: 'Linear webhookCreate succeeded but webhookDelete of old failed — manual cleanup needed' };
	}

	return {
		ok: true,
		finalValue: newWebhook.secret,
		upstreamApplied: [`linear: replaced webhook ${match.id} → ${newWebhook.id}`],
	};
};
