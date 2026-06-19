#!/usr/bin/env bun
/**
 * Secret-rotation driver.
 *
 * Reads registry.json, decides what's due (per cadenceDays + last-
 * rotation date in audit/), calls the rotator, writes the new value
 * to Infisical (rspace/prod), appends an audit-log entry, and at the
 * end emails Jeff a summary.
 *
 * Usage:
 *   bun run rotate.ts                          rotate everything due
 *   bun run rotate.ts --dry-run                show what would rotate
 *   bun run rotate.ts --secret KEY             rotate one secret only
 *   bun run rotate.ts --secret KEY --force     ignore cadence
 *
 * After successful rotations, the driver invokes /opt/rspace-online/deploy.sh
 * over SSH so the new secrets get baked into the next rspace container.
 */
import { existsSync, mkdirSync, appendFileSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { randomBytes } from 'node:crypto';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import { infisicalUpsert } from './rotators/_infisical';
import type { Rotator, RotateResult } from './rotators/_types';
import { internalRotator } from './rotators/internal';
import { giteaRotator } from './rotators/gitea';
import { githubRotator } from './rotators/github';
import { gitlabRotator } from './rotators/gitlab';
import { linearRotator } from './rotators/linear';
import { calcomRotator } from './rotators/calcom';
import { sentryRotator } from './rotators/sentry';
import { telegramRotator } from './rotators/telegram';
import { posthogRotator } from './rotators/posthog';
import { mattermostRotator } from './rotators/mattermost';
import { postgresRotator } from './rotators/postgres';

const ROTATORS: Record<string, Rotator> = {
	internal: internalRotator,
	gitea: giteaRotator,
	github: githubRotator,
	gitlab: gitlabRotator,
	linear: linearRotator,
	calcom: calcomRotator,
	sentry: sentryRotator,
	telegram: telegramRotator,
	posthog: posthogRotator,
	mattermost: mattermostRotator,
	postgres: postgresRotator,
};

const HERE = dirname(fileURLToPath(import.meta.url));
const REGISTRY_PATH = join(HERE, 'registry.json');
const AUDIT_DIR = join(HERE, 'audit');

interface SecretEntry {
	readonly name: string;
	readonly rotator: string;
	readonly cadenceDays: number;
	readonly config: Record<string, unknown>;
}

interface AuditEntry {
	readonly ts: string;
	readonly secret: string;
	readonly result: 'rotated' | 'failed' | 'skipped' | 'dry-run';
	readonly rotator: string;
	readonly upstreamApplied?: ReadonlyArray<string>;
	readonly error?: string;
}

function loadRegistry(): SecretEntry[] {
	const raw = JSON.parse(readFileSync(REGISTRY_PATH, 'utf8')) as { secrets: SecretEntry[] };
	return raw.secrets.filter((s) => typeof s.name === 'string' && typeof s.rotator === 'string');
}

function generateValue(secretName: string): string {
	// flags = simple value
	if (secretName === 'HN_ENABLED') return '1';
	// default: 32-byte hex
	return randomBytes(32).toString('hex');
}

function lastRotationFor(name: string): Date | null {
	if (!existsSync(AUDIT_DIR)) return null;
	const files = readdirSync(AUDIT_DIR).filter((f) => f.endsWith('.jsonl')).sort().reverse();
	for (const f of files) {
		const lines = readFileSync(join(AUDIT_DIR, f), 'utf8').split('\n').filter((l) => l.length > 0);
		for (let i = lines.length - 1; i >= 0; i--) {
			try {
				const e = JSON.parse(lines[i]) as AuditEntry;
				if (e.secret === name && e.result === 'rotated') return new Date(e.ts);
			} catch { /* skip */ }
		}
	}
	return null;
}

function isDue(entry: SecretEntry): boolean {
	const last = lastRotationFor(entry.name);
	if (!last) return true;
	const elapsedDays = (Date.now() - last.getTime()) / (24 * 3600 * 1000);
	return elapsedDays >= entry.cadenceDays;
}

function appendAudit(e: AuditEntry): void {
	mkdirSync(AUDIT_DIR, { recursive: true });
	const day = new Date().toISOString().slice(0, 10);
	const file = join(AUDIT_DIR, `${day}.jsonl`);
	appendFileSync(file, JSON.stringify(e) + '\n', 'utf8');
}

function triggerDeploy(): Promise<{ ok: boolean; stderr: string }> {
	return new Promise((resolve) => {
		const p = spawn('ssh', ['netcup-full', '/opt/rspace-online/deploy.sh'], { stdio: ['ignore', 'ignore', 'pipe'] });
		let stderr = '';
		p.stderr.on('data', (d) => stderr += d.toString());
		p.on('close', (code) => resolve({ ok: code === 0, stderr }));
	});
}

interface Cli {
	readonly dryRun: boolean;
	readonly only?: string;
	readonly force: boolean;
}

function parseCli(argv: ReadonlyArray<string>): Cli {
	const args = argv.slice(2);
	const dryRun = args.includes('--dry-run');
	const force = args.includes('--force');
	const i = args.indexOf('--secret');
	const only = i >= 0 && i < args.length - 1 ? args[i + 1] : undefined;
	return { dryRun, only, force };
}

async function main(): Promise<void> {
	const cli = parseCli(process.argv);
	const reg = loadRegistry();
	const candidates = reg.filter((s) => (cli.only ? s.name === cli.only : true));
	const results: AuditEntry[] = [];

	for (const entry of candidates) {
		if (entry.rotator === 'noop') continue;
		if (entry.rotator === 'manual') {
			const last = lastRotationFor(entry.name);
			const elapsedDays = last ? (Date.now() - last.getTime()) / (24 * 3600 * 1000) : Infinity;
			if (elapsedDays >= entry.cadenceDays) {
				const audit: AuditEntry = {
					ts: new Date().toISOString(), secret: entry.name, result: 'skipped',
					rotator: 'manual',
					error: `MANUAL ROTATION DUE (last=${last?.toISOString() ?? 'never'}, cadence=${entry.cadenceDays}d, where=${(entry.config.rotateAt as string) ?? '?'})`,
				};
				appendAudit(audit); results.push(audit);
			}
			continue;
		}
		if (!cli.force && !isDue(entry)) continue;
		const rotator = ROTATORS[entry.rotator];
		if (!rotator) {
			const audit: AuditEntry = {
				ts: new Date().toISOString(), secret: entry.name, result: 'failed',
				rotator: entry.rotator, error: `unknown rotator: ${entry.rotator}`,
			};
			appendAudit(audit); results.push(audit);
			continue;
		}
		const newValue = generateValue(entry.name);
		if (cli.dryRun) {
			const audit: AuditEntry = {
				ts: new Date().toISOString(), secret: entry.name, result: 'dry-run', rotator: entry.rotator,
			};
			appendAudit(audit); results.push(audit);
			continue;
		}

		let res: RotateResult;
		try {
			res = await rotator({ secretName: entry.name, oldValue: '', newValue, config: entry.config });
		} catch (err) {
			res = { ok: false, error: err instanceof Error ? err.message : String(err) };
		}
		if (!res.ok) {
			const audit: AuditEntry = {
				ts: new Date().toISOString(), secret: entry.name, result: 'failed',
				rotator: entry.rotator, error: res.error,
			};
			appendAudit(audit); results.push(audit);
			continue;
		}

		try {
			await infisicalUpsert(entry.name, res.finalValue ?? newValue);
		} catch (err) {
			const audit: AuditEntry = {
				ts: new Date().toISOString(), secret: entry.name, result: 'failed',
				rotator: entry.rotator,
				error: `upstream OK but Infisical write FAILED — manual sync needed: ${err instanceof Error ? err.message : err}`,
				upstreamApplied: res.upstreamApplied,
			};
			appendAudit(audit); results.push(audit);
			continue;
		}

		const audit: AuditEntry = {
			ts: new Date().toISOString(), secret: entry.name, result: 'rotated',
			rotator: entry.rotator, upstreamApplied: res.upstreamApplied,
		};
		appendAudit(audit); results.push(audit);
	}

	const rotatedCount = results.filter((r) => r.result === 'rotated').length;
	const failedCount = results.filter((r) => r.result === 'failed').length;
	const manualCount = results.filter((r) => r.result === 'skipped' && r.error?.startsWith('MANUAL')).length;

	if (rotatedCount > 0 && !cli.dryRun) {
		const dep = await triggerDeploy();
		console.log(`deploy: ${dep.ok ? 'OK' : 'FAILED — ' + dep.stderr.trim()}`);
	}

	console.log(`\nrotation summary: ${rotatedCount} rotated, ${failedCount} failed, ${manualCount} manual-due`);
	if (results.length === 0) console.log('(nothing due)');
	for (const r of results) {
		const tag = r.result === 'rotated' ? '✓'
			: r.result === 'failed' ? '✗'
			: r.result === 'skipped' ? '!'
			: '·';
		console.log(`  ${tag} ${r.secret.padEnd(28)} ${r.result.padEnd(8)} ${r.error ?? (r.upstreamApplied ?? []).join(',')}`);
	}

	// Email summary if anything actionable happened
	if (rotatedCount + failedCount + manualCount > 0 && !cli.dryRun) {
		try {
			const summary = results.map((r) => `${r.result.padEnd(8)} ${r.secret} ${r.error ?? ''}`).join('\n');
			const subject = `Secret rotation — ${rotatedCount} rotated, ${failedCount} failed, ${manualCount} manual-due`;
			const footer = manualCount > 0
				? `\nManual-due tasks above need action — do them in Infisical at https://secrets.jeffemmett.com (rspace/prod), per each secret's "where=" instruction.\n`
				: '';
			const body = `${subject}\n\n${summary}\n${footer}`;
			// Alert recipient: jeffemmett@gmail.com (Jeff's explicit choice for rotation prompts).
			const cmd = `printf '%s' '${body.replace(/'/g, `'"'"'`)}' | mail -s '${subject.replace(/'/g, `'"'"'`)}' jeffemmett@gmail.com 2>/dev/null || true`;
			spawn('sh', ['-c', cmd], { stdio: 'ignore' });
		} catch { /* notification is best-effort */ }
	}

	if (failedCount > 0) process.exit(1);
}

await main();
