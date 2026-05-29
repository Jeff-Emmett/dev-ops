/**
 * Postgres user password rotator.
 *
 * Runs `ALTER USER <user> WITH PASSWORD '<new>'` inside the DB container
 * via docker exec on the Netcup host. This means the rotation driver
 * MUST be run from a host with SSH access to netcup-full (i.e. the
 * same host you run deploy.sh from).
 *
 * Sequencing:
 *   1. ALTER USER on the live DB
 *   2. Infisical write happens in the driver
 *   3. Driver triggers rspace redeploy after Infisical write
 *
 * Between step 1 and step 3 there IS a window where the DB has the new
 * password but rspace is still running with the old one — Postgres
 * connections that were already established stay alive (libpq doesn't
 * re-auth mid-connection), so this window is safe AS LONG AS no service
 * reconnects mid-rotation. The redeploy after step 2 forces a clean
 * cutover.
 *
 * config: container, dbUser, dbName, sshHost (default 'netcup-full').
 */
import { spawn } from 'node:child_process';
import type { Rotator } from './_types';

function runSsh(host: string, cmd: string, input?: string): Promise<{ ok: boolean; stdout: string; stderr: string }> {
	return new Promise((resolve) => {
		const proc = spawn('ssh', [host, cmd], { stdio: ['pipe', 'pipe', 'pipe'] });
		let stdout = '', stderr = '';
		proc.stdout.on('data', (d) => stdout += d.toString());
		proc.stderr.on('data', (d) => stderr += d.toString());
		if (input) { proc.stdin.write(input); proc.stdin.end(); }
		proc.on('close', (code) => resolve({ ok: code === 0, stdout, stderr }));
	});
}

export const postgresRotator: Rotator = async ({ newValue, config }) => {
	const container = config.container as string | undefined;
	const dbUser = config.dbUser as string | undefined;
	const dbName = config.dbName as string | undefined;
	const sshHost = (config.sshHost as string) || 'netcup-full';
	if (!container || !dbUser || !dbName) {
		return { ok: false, error: 'config.container/dbUser/dbName required' };
	}
	if (newValue.includes("'") || newValue.includes('\\')) {
		return { ok: false, error: 'generated password contains shell-unsafe characters — regenerate' };
	}

	const sql = `ALTER USER "${dbUser}" WITH PASSWORD '${newValue}';`;
	const cmd = `docker exec -i ${container} psql -U ${dbUser} -d ${dbName} -v ON_ERROR_STOP=1 -c "${sql.replace(/"/g, '\\"')}"`;

	const r = await runSsh(sshHost, cmd);
	if (!r.ok) return { ok: false, error: `pg ALTER USER failed: ${r.stderr.trim() || r.stdout.trim()}` };

	return {
		ok: true,
		upstreamApplied: [`pg:${container}/ALTER USER ${dbUser}`],
	};
};
