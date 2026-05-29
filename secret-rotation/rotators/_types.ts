/**
 * Common rotator contract. Each per-platform rotator implements this
 * single function. Returning ok=false aborts the rotation for that secret
 * (Infisical is NOT updated unless the upstream platform accepted the new
 * value first) so we don't end up out of sync.
 */
export interface RotateContext {
	readonly secretName: string;
	readonly oldValue: string;
	readonly newValue: string;
	readonly config: Record<string, unknown>;
}

export interface RotateResult {
	readonly ok: boolean;
	readonly upstreamApplied?: ReadonlyArray<string>;
	readonly error?: string;
	/**
	 * If the upstream platform GENERATES the secret (Sentry internal
	 * integrations, PostHog destinations) rather than ACCEPTING one we
	 * set, the rotator returns the platform-issued value here and the
	 * driver writes THAT (not the locally-generated newValue) to
	 * Infisical. For us-set rotators (gitea, github, telegram, etc.)
	 * leave this undefined.
	 */
	readonly finalValue?: string;
}

export type Rotator = (ctx: RotateContext) => Promise<RotateResult>;
