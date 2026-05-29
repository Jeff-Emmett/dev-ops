/**
 * Mattermost outgoing-webhook token rotator.
 *
 * PUT /api/v4/hooks/outgoing/{hook_id} accepts a `token` field directly,
 * so we can set our locally-generated value.
 *
 * Auth: MATTERMOST_API_PAT from Infisical (Personal Access Token from
 * Account Settings → Security → Personal Access Tokens).
 * config.host = your Mattermost server.
 * config.webhookId = the outgoing webhook id (UI URL contains it).
 */
import { infisicalGet } from './_infisical';
import type { Rotator } from './_types';

interface OutgoingHook {
	id: string; token: string; team_id: string; channel_id: string;
	display_name: string; description: string; trigger_words: string[];
	callback_urls: string[]; content_type: string;
}

export const mattermostRotator: Rotator = async ({ newValue, config }) => {
	const pat = await infisicalGet('MATTERMOST_API_PAT');
	if (!pat) return { ok: false, error: 'MATTERMOST_API_PAT missing in Infisical' };
	const host = config.host as string | undefined;
	const webhookId = config.webhookId as string | undefined;
	if (!host || !webhookId) {
		return { ok: false, error: 'config.host or .webhookId missing in registry.json' };
	}
	const headers = { authorization: `Bearer ${pat}`, 'content-type': 'application/json' };

	const getRes = await fetch(`${host}/api/v4/hooks/outgoing/${webhookId}`, { headers });
	if (!getRes.ok) return { ok: false, error: `mattermost GET HTTP ${getRes.status}` };
	const hook = await getRes.json() as OutgoingHook;

	const putRes = await fetch(`${host}/api/v4/hooks/outgoing/${webhookId}`, {
		method: 'PUT', headers,
		body: JSON.stringify({ ...hook, token: newValue }),
	});
	if (!putRes.ok) return { ok: false, error: `mattermost PUT HTTP ${putRes.status}` };

	return { ok: true, upstreamApplied: [`mattermost:hook/${webhookId}`] };
};
