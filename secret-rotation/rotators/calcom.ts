/**
 * Cal.com webhook secret rotator.
 *
 * Cal.com's v1 API: PATCH /v1/webhooks/{id} accepts `secret` directly,
 * so we can set our locally-generated value.
 *
 * Auth: CALCOM_API_KEY from Infisical (user API key from Cal.com
 * Settings → Developer → API keys).
 */
import { infisicalGet } from './_infisical';
import type { Rotator } from './_types';

const HOST = 'https://api.cal.com';

interface CalcomWebhook { id: string; subscriberUrl?: string; }

export const calcomRotator: Rotator = async ({ newValue, config }) => {
	const apiKey = await infisicalGet('CALCOM_API_KEY');
	if (!apiKey) return { ok: false, error: 'CALCOM_API_KEY missing in Infisical' };
	const pattern = (config.rspaceWebhookUrlPattern as string) || 'rspace.online/api/bridges/calcom/webhook';

	const listRes = await fetch(`${HOST}/v1/webhooks?apiKey=${apiKey}`);
	if (!listRes.ok) return { ok: false, error: `calcom list HTTP ${listRes.status}` };
	const body = await listRes.json() as { webhooks?: CalcomWebhook[] };
	const matches = (body.webhooks ?? []).filter((w) => w.subscriberUrl?.includes(pattern));
	if (matches.length === 0) return { ok: false, error: 'no Cal.com webhook matches the rspace URL pattern' };

	const applied: string[] = [];
	for (const w of matches) {
		const patchRes = await fetch(`${HOST}/v1/webhooks/${w.id}?apiKey=${apiKey}`, {
			method: 'PATCH',
			headers: { 'content-type': 'application/json' },
			body: JSON.stringify({ secret: newValue }),
		});
		if (!patchRes.ok) return { ok: false, error: `calcom PATCH ${w.id} HTTP ${patchRes.status}` };
		applied.push(`calcom:webhook/${w.id}`);
	}
	return { ok: true, upstreamApplied: applied };
};
