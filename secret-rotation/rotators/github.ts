/**
 * GitHub repo-webhook rotator.
 *
 * For each repo in config.repos, find the webhook matching the
 * rspaceWebhookUrlPattern and PATCH its config.secret to the new value.
 *
 * Auth: GITHUB_ROTATION_TOKEN read from ~/.secrets/github_rotation_token,
 * a fine-grained PAT with "Webhooks: Read & write" repo permission.
 *
 * If config.repos is empty, the rotator scans the authenticated user's
 * repos via /user/repos and updates every matching hook found.
 */
import { readFileSync } from 'node:fs';
import type { Rotator } from './_types';

function realHome(): string {
	const h = process.env.HOME ?? '';
	if (h && !h.includes('/snap/')) return h;
	return '/home/jeffe';
}

interface GhRepo { full_name: string; owner: { login: string }; name: string; }
interface GhHook { id: number; config: { url?: string; secret?: string; content_type?: string; insecure_ssl?: string }; }

function getToken(): string {
	try {
		return readFileSync(`${realHome()}/.secrets/github_rotation_token`, 'utf8').trim();
	} catch {
		throw new Error('missing ~/.secrets/github_rotation_token (PAT with Webhooks read/write)');
	}
}

export const githubRotator: Rotator = async ({ newValue, config }) => {
	const pattern = (config.rspaceWebhookUrlPattern as string) || 'rspace.online/api/bridges/github/webhook';
	const explicit = (config.repos as ReadonlyArray<string>) || [];
	const token = getToken();
	const headers = { authorization: `Bearer ${token}`, accept: 'application/vnd.github+json' };

	let repos: GhRepo[];
	if (explicit.length > 0) {
		repos = explicit.map((full) => {
			const [owner, name] = full.split('/');
			return { full_name: full, owner: { login: owner }, name };
		});
	} else {
		const all: GhRepo[] = [];
		let page = 1;
		while (true) {
			const res = await fetch(`https://api.github.com/user/repos?per_page=100&page=${page}`, { headers });
			if (!res.ok) return { ok: false, error: `github list repos HTTP ${res.status}` };
			const batch = await res.json() as GhRepo[];
			if (batch.length === 0) break;
			all.push(...batch);
			if (batch.length < 100) break;
			page++;
		}
		repos = all;
	}

	const applied: string[] = [];
	for (const repo of repos) {
		const hooksRes = await fetch(`https://api.github.com/repos/${repo.owner.login}/${repo.name}/hooks`, { headers });
		if (!hooksRes.ok) continue;
		const hooks = await hooksRes.json() as GhHook[];
		for (const hook of hooks) {
			if (!hook.config.url?.includes(pattern)) continue;
			const patchRes = await fetch(`https://api.github.com/repos/${repo.owner.login}/${repo.name}/hooks/${hook.id}/config`, {
				method: 'PATCH',
				headers: { ...headers, 'content-type': 'application/json' },
				body: JSON.stringify({
					url: hook.config.url,
					content_type: hook.config.content_type ?? 'json',
					insecure_ssl: hook.config.insecure_ssl ?? '0',
					secret: newValue,
				}),
			});
			if (!patchRes.ok) {
				return { ok: false, error: `github PATCH ${repo.full_name}/hooks/${hook.id} HTTP ${patchRes.status}` };
			}
			applied.push(`${repo.full_name}/hooks/${hook.id}`);
		}
	}
	return { ok: true, upstreamApplied: applied };
};
