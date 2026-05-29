/**
 * Sentry internal-integration client-secret rotator.
 *
 * Sentry generates the signing secret server-side. Rotation = POST
 * /api/0/sentry-app-installations/{install}/external-issues/.../rotate
 * — actually the right endpoint is
 *   POST /api/0/sentry-apps/{slug}/rotate-secret/
 * which returns { clientSecret: <new> } in the JSON body.
 *
 * Auth: SENTRY_USER_API_TOKEN with org:write scope (Settings → Account →
 * API → Auth Tokens). Plus the integration slug in config.sentryAppSlug.
 */
import { infisicalGet } from './_infisical';
import type { Rotator } from './_types';

export const sentryRotator: Rotator = async ({ config }) => {
	const apiKey = await infisicalGet('SENTRY_USER_API_TOKEN');
	if (!apiKey) return { ok: false, error: 'SENTRY_USER_API_TOKEN missing in Infisical' };
	const slug = config.sentryAppSlug as string | undefined;
	if (!slug) return { ok: false, error: 'config.sentryAppSlug not set in registry.json' };

	const res = await fetch(`https://sentry.io/api/0/sentry-apps/${slug}/rotate-secret/`, {
		method: 'POST',
		headers: { authorization: `Bearer ${apiKey}` },
	});
	if (!res.ok) return { ok: false, error: `sentry rotate HTTP ${res.status}` };
	const body = await res.json() as { clientSecret?: string };
	if (!body.clientSecret) return { ok: false, error: 'Sentry rotate response had no clientSecret' };

	return {
		ok: true,
		finalValue: body.clientSecret,
		upstreamApplied: [`sentry:apps/${slug}/rotate-secret`],
	};
};
