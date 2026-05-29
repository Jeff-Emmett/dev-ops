/**
 * PostHog webhook-destination signing-secret rotator.
 *
 * PostHog generates the signing secret on the destination. Rotation =
 * PATCH /api/projects/{project_id}/pipeline_destination_configs/{id}/
 * with regenerate_signing_secret=true, then read the returned config.
 *
 * Auth: POSTHOG_PERSONAL_API_KEY from Infisical (User → Personal API keys).
 * config: posthogProjectId, posthogDestinationId, host (default us.posthog.com).
 */
import { infisicalGet } from './_infisical';
import type { Rotator } from './_types';

export const posthogRotator: Rotator = async ({ config }) => {
	const apiKey = await infisicalGet('POSTHOG_PERSONAL_API_KEY');
	if (!apiKey) return { ok: false, error: 'POSTHOG_PERSONAL_API_KEY missing in Infisical' };
	const host = (config.host as string) || 'https://us.posthog.com';
	const projectId = config.posthogProjectId as string | undefined;
	const destId = config.posthogDestinationId as string | undefined;
	if (!projectId || !destId) {
		return { ok: false, error: 'config.posthogProjectId or .posthogDestinationId missing in registry.json' };
	}

	const res = await fetch(`${host}/api/projects/${projectId}/pipeline_destination_configs/${destId}/`, {
		method: 'PATCH',
		headers: { authorization: `Bearer ${apiKey}`, 'content-type': 'application/json' },
		body: JSON.stringify({ regenerate_signing_secret: true }),
	});
	if (!res.ok) return { ok: false, error: `posthog PATCH HTTP ${res.status}` };
	const body = await res.json() as { signing_secret?: string };
	if (!body.signing_secret) return { ok: false, error: 'PostHog response had no signing_secret' };

	return {
		ok: true,
		finalValue: body.signing_secret,
		upstreamApplied: [`posthog:project/${projectId}/dest/${destId}`],
	};
};
