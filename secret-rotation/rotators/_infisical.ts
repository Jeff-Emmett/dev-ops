/**
 * Infisical write API for the rspace/prod project.
 *
 * Auth: claude-ops UA token (cross-project Developer role on rspace,
 * confirmed 2026-05-29). CF Access headers also required because
 * secrets.jeffemmett.com sits behind a CF Access policy.
 */
import { readFileSync } from 'node:fs';

const INFISICAL_URL = 'https://secrets.jeffemmett.com';
const RSPACE_PROJECT = '5aac84af-0792-4857-a469-75485aad6d3b';
const ENV = 'prod';

function realHome(): string {
	// process.env.HOME / os.homedir() can return the snap-sandboxed path
	// (~/snap/bun-js/<rev>) when bun is installed via snap. Prefer SUDO_USER
	// or the explicit HOME if it's not sandboxed; else hardcode.
	const h = process.env.HOME ?? '';
	if (h && !h.includes('/snap/')) return h;
	return '/home/jeffe';
}

function readSecret(file: string): string {
	return readFileSync(`${realHome()}/.secrets/${file}`, 'utf8').trim();
}

async function getToken(): Promise<string> {
	const clientId = readSecret('infisical_admin_client_id');
	const clientSecret = readSecret('infisical_admin_client_secret');
	const cfId = readSecret('cf_access_infisical_client_id');
	const cfSec = readSecret('cf_access_infisical_client_secret');
	const res = await fetch(`${INFISICAL_URL}/api/v1/auth/universal-auth/login`, {
		method: 'POST',
		headers: {
			'content-type': 'application/json',
			'cf-access-client-id': cfId,
			'cf-access-client-secret': cfSec,
		},
		body: JSON.stringify({ clientId, clientSecret }),
	});
	if (!res.ok) throw new Error(`infisical auth failed: ${res.status}`);
	const body = await res.json() as { accessToken?: string };
	if (!body.accessToken) throw new Error('infisical: no accessToken in response');
	return body.accessToken;
}

function cfHeaders(): Record<string, string> {
	return {
		'cf-access-client-id': readSecret('cf_access_infisical_client_id'),
		'cf-access-client-secret': readSecret('cf_access_infisical_client_secret'),
	};
}

export async function infisicalGet(key: string): Promise<string | null> {
	const token = await getToken();
	const url = `${INFISICAL_URL}/api/v3/secrets/raw/${encodeURIComponent(key)}?workspaceId=${RSPACE_PROJECT}&environment=${ENV}&secretPath=%2F`;
	const res = await fetch(url, {
		headers: { authorization: `Bearer ${token}`, ...cfHeaders() },
	});
	if (res.status === 404) return null;
	if (!res.ok) throw new Error(`infisical get ${key} HTTP ${res.status}`);
	const body = await res.json() as { secret?: { secretValue?: string } };
	return body.secret?.secretValue ?? null;
}

export async function infisicalUpsert(key: string, value: string): Promise<void> {
	const token = await getToken();
	const headers = {
		authorization: `Bearer ${token}`,
		'content-type': 'application/json',
		...cfHeaders(),
	};
	const body = JSON.stringify({
		workspaceId: RSPACE_PROJECT,
		environment: ENV,
		secretPath: '/',
		secretValue: value,
		type: 'shared',
	});

	const created = await fetch(`${INFISICAL_URL}/api/v3/secrets/raw/${encodeURIComponent(key)}`, {
		method: 'POST', headers, body,
	});
	if (created.ok) return;
	if (created.status === 400 || created.status === 409) {
		const updated = await fetch(`${INFISICAL_URL}/api/v3/secrets/raw/${encodeURIComponent(key)}`, {
			method: 'PATCH', headers, body,
		});
		if (!updated.ok) {
			throw new Error(`infisical PATCH ${key} HTTP ${updated.status}: ${await updated.text()}`);
		}
		return;
	}
	throw new Error(`infisical POST ${key} HTTP ${created.status}: ${await created.text()}`);
}

export async function infisicalGetMany(keys: ReadonlyArray<string>): Promise<Record<string, string | null>> {
	const out: Record<string, string | null> = {};
	for (const k of keys) {
		try { out[k] = await infisicalGet(k); }
		catch { out[k] = null; }
	}
	return out;
}

export function readLocalSecret(filename: string): string {
	return readSecret(filename);
}
