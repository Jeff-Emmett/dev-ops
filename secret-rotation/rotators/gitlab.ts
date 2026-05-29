/**
 * GitLab project-webhook rotator.
 *
 * For each project id in config.projectIds, find the webhook matching
 * the rspaceWebhookUrlPattern and PUT its token to the new value.
 *
 * Auth: GITLAB_ROTATION_TOKEN read from ~/.secrets/gitlab_rotation_token
 * (PAT or group access token with api scope).
 */
import { readFileSync } from 'node:fs';
import type { Rotator } from './_types';

function realHome(): string {
	const h = process.env.HOME ?? '';
	if (h && !h.includes('/snap/')) return h;
	return '/home/jeffe';
}

interface GlHook { id: number; url: string; }

function getToken(): string {
	try {
		return readFileSync(`${realHome()}/.secrets/gitlab_rotation_token`, 'utf8').trim();
	} catch {
		throw new Error('missing ~/.secrets/gitlab_rotation_token (PAT with api scope)');
	}
}

export const gitlabRotator: Rotator = async ({ newValue, config }) => {
	const host = (config.host as string) || 'https://gitlab.com';
	const pattern = (config.rspaceWebhookUrlPattern as string) || 'rspace.online/api/bridges/gitlab/webhook';
	const projectIds = (config.projectIds as ReadonlyArray<number | string>) || [];
	if (projectIds.length === 0) {
		return { ok: true, upstreamApplied: [], error: 'no projectIds configured — rotation skipped' };
	}
	const token = getToken();
	const headers = { 'private-token': token };

	const applied: string[] = [];
	for (const pid of projectIds) {
		const hooksRes = await fetch(`${host}/api/v4/projects/${pid}/hooks`, { headers });
		if (!hooksRes.ok) return { ok: false, error: `gitlab list hooks for ${pid} HTTP ${hooksRes.status}` };
		const hooks = await hooksRes.json() as GlHook[];
		for (const hook of hooks) {
			if (!hook.url?.includes(pattern)) continue;
			const putRes = await fetch(`${host}/api/v4/projects/${pid}/hooks/${hook.id}?token=${encodeURIComponent(newValue)}`, {
				method: 'PUT', headers,
			});
			if (!putRes.ok) return { ok: false, error: `gitlab PUT ${pid}/hooks/${hook.id} HTTP ${putRes.status}` };
			applied.push(`project:${pid}/hooks/${hook.id}`);
		}
	}
	return { ok: true, upstreamApplied: applied };
};
