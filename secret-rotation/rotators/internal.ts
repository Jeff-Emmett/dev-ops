/**
 * "Internal" rotator — for secrets that only exist inside our own
 * infrastructure (no upstream platform to sync with). Examples:
 *
 *   - DISCORD_RELAY_SECRET     (HMAC shared with a relay we maintain)
 *   - INBOX_ADMIN_TOKEN        (admin token consumed only by rspace itself)
 *
 * Rotation = no-op upstream + Infisical write happens in the driver.
 */
import type { Rotator } from './_types';

export const internalRotator: Rotator = async () => ({
	ok: true,
	upstreamApplied: [],
});
