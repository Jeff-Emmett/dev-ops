/**
 * Telegram bot URL-secret rotator.
 *
 * Telegram bots verify webhooks via a secret embedded in the webhook URL
 * (we use `https://rspace.online/api/bridges/telegram/webhook/<secret>`).
 * On each rotation we call /bot<TOKEN>/setWebhook with the new URL.
 *
 * Auth: TELEGRAM_BOT_TOKEN (the long-lived BotFather token, NOT the
 * url-secret) read from Infisical at runtime so it stays sealed.
 */
import { infisicalGet } from './_infisical';
import type { Rotator } from './_types';

export const telegramRotator: Rotator = async ({ newValue }) => {
	const botToken = await infisicalGet('TELEGRAM_BOT_TOKEN');
	if (!botToken) {
		return { ok: false, error: 'TELEGRAM_BOT_TOKEN missing in Infisical — cannot call setWebhook' };
	}
	const url = `https://rspace.online/api/bridges/telegram/webhook/${encodeURIComponent(newValue)}`;
	const res = await fetch(`https://api.telegram.org/bot${botToken}/setWebhook`, {
		method: 'POST',
		headers: { 'content-type': 'application/json' },
		body: JSON.stringify({ url, allowed_updates: ['message', 'callback_query'] }),
	});
	if (!res.ok) return { ok: false, error: `telegram setWebhook HTTP ${res.status}` };
	const body = await res.json() as { ok?: boolean; description?: string };
	if (!body.ok) return { ok: false, error: `telegram setWebhook returned ok=false: ${body.description ?? ''}` };
	return { ok: true, upstreamApplied: [`setWebhook(${url.replace(newValue, '<redacted>')})`] };
};
