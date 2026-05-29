/**
 * Gitea repo-webhook rotator.
 *
 * For each repo in config.repos, find the hook whose URL contains
 * config.rspaceWebhookUrlPattern and PATCH its `secret` to the new value.
 * Authenticates via GITEA_ROTATION_TOKEN read from
 * `~/.secrets/gitea_rotation_token` (a PAT with `write:repository_hooks`
 * scope).
 *
 * If config.repos is empty, the rotator probes all user repos via
 * /api/v1/user/repos and updates every matching hook found.
 */
import { readFileSync } from 'node:fs';
import type { Rotator } from './_types';

function realHome(): string {
	const h = process.env.HOME ?? '';
	if (h && !h.includes('/snap/')) return h;
	return '/home/jeffe';
}

interface GiteaRepo { full_name: string; owner: { login: string }; name: string; }
interface GiteaHook { id: number; type: string; config: { url?: string }; }

function getToken(): string {
	try {
		return readFileSync(`${realHome()}/.secrets/gitea_rotation_token`, 'utf8').trim();
	} catch {
		throw new Error('missing ~/.secrets/gitea_rotation_token (PAT with write:repository_hooks)');
	}
}

export const giteaRotator: Rotator = async ({ newValue, config }) => {
	const host = (config.host as string) || 'https://gitea.jeffemmett.com';
	const pattern = (config.rspaceWebhookUrlPattern as string) || 'rspace.online/api/bridges/gitea/webhook';
	const explicitRepos = (config.repos as ReadonlyArray<string>) || [];
	const token = getToken();
	const headers = { authorization: `token ${token}` };

	let repos: GiteaRepo[];
	if (explicitRepos.length > 0) {
		repos = explicitRepos.map((full) => {
			const [owner, name] = full.split('/');
			return { full_name: full, owner: { login: owner }, name };
		});
	} else {
		const allRepos: GiteaRepo[] = [];
		let page = 1;
		while (true) {
			const res = await fetch(`${host}/api/v1/user/repos?page=${page}&limit=50`, { headers });
			if (!res.ok) return { ok: false, error: `gitea list repos HTTP ${res.status}` };
			const batch = await res.json() as GiteaRepo[];
			if (batch.length === 0) break;
			allRepos.push(...batch);
			if (batch.length < 50) break;
			page++;
		}
		repos = allRepos;
	}

	const applied: string[] = [];
	for (const repo of repos) {
		const hooksRes = await fetch(`${host}/api/v1/repos/${repo.owner.login}/${repo.name}/hooks`, { headers });
		if (!hooksRes.ok) continue;
		const hooks = await hooksRes.json() as GiteaHook[];
		for (const hook of hooks) {
			if (!hook.config.url?.includes(pattern)) continue;
			const patchRes = await fetch(`${host}/api/v1/repos/${repo.owner.login}/${repo.name}/hooks/${hook.id}`, {
				method: 'PATCH',
				headers: { ...headers, 'content-type': 'application/json' },
				body: JSON.stringify({ config: { ...hook.config, secret: newValue } }),
			});
			if (!patchRes.ok) {
				return { ok: false, error: `gitea PATCH ${repo.full_name}/hooks/${hook.id} HTTP ${patchRes.status}` };
			}
			applied.push(`${repo.full_name}/hooks/${hook.id}`);
		}
	}
	return { ok: true, upstreamApplied: applied };
};
