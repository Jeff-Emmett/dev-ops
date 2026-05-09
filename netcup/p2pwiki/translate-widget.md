# Translation widget for wiki.p2pfoundation.net

Implements TASK-MEDIUM.13. Replaces the retired p2pwikifr (TASK-MEDIUM.14) with
on-demand client-side Google Translate. Zero server-side resources, zero API
keys, no DB changes.

## What it does

Injects a small floating language picker (top-right) on every read page of
wiki.p2pfoundation.net. User clicks → page is translated by Google Translate
in the browser. Source EN page is unchanged so Cloudflare cache still works.

Skipped on: special pages, edit/history/submit/delete actions.

Languages: FR, ES, DE, PT, IT, NL, JA, zh-CN.

## Why Google MT and not DeepL?

DeepL has no client-side widget — their API is server-side only. Using DeepL
would require a Netcup-hosted proxy (server-side, API key in env, possibly
caching layer). That's a Phase 2 if traffic + quality demand it.

Google's element.js widget works zero-config and has been stable since 2010.
Quality on academic/governance vocabulary is mediocre but adequate for
read-access. The dormant wikifr (0 edits in 90 days, 0 active editors) had a
small audience to begin with.

## Deployment

1. **Copy file to wiki container's host bind mount**
   ```
   ssh netcup-full 'mkdir -p /opt/websites/p2pwiki/extensions'
   scp dev-ops/netcup/p2pwiki/translate-widget.php \
       netcup-full:/opt/websites/p2pwiki/extensions/translate-widget.php
   ```

2. **Mount the extensions dir into the container**
   Edit `/opt/websites/p2pwiki/docker-compose.yml`, add to the `p2pwiki` service's
   `volumes:`:
   ```
   - ./extensions:/var/www/html/extensions/p2pwiki-custom:ro
   ```
   (Mount under a dedicated subdir to avoid clobbering MediaWiki's own extensions.)

3. **Add to LocalSettings.php**
   Append at the bottom of `/opt/websites/p2pwiki/LocalSettings.php`:
   ```php
   require_once "$IP/extensions/p2pwiki-custom/translate-widget.php";
   ```

4. **Reload PHP**
   ```
   ssh netcup-full 'cd /opt/websites/p2pwiki && docker compose up -d p2pwiki'
   ```
   No force-recreate needed; LocalSettings.php is reread on next request because
   MediaWiki's PHP-FPM process pool reloads it. If unsure, restart explicitly.

5. **Smoke test**
   - Visit https://wiki.p2pfoundation.net/Commons-based_peer_production
   - Verify the floating widget appears top-right
   - Pick "Français" — page text should translate
   - Visit `?action=edit` on any page — widget must NOT appear
   - Visit `Special:RecentChanges` — widget must NOT appear

## Rollback

Comment out the `require_once` line in LocalSettings.php and reload. Next page
load will not have the widget. Or delete the file entirely.

## Phase 2 (DeepL)

If translation quality matters more than zero-ops:
1. Deploy a small Bun/Express proxy on Netcup (~30 MB RAM) that:
   - Accepts `POST /api/translate {text, target_lang}` from the client widget
   - Calls DeepL Free API with the server's API key
   - Returns translated text
   - Caches per-(text, lang) for 24h in memory
2. Replace the Google `element.js` import in `translate-widget.php` with custom
   JS that calls the proxy, mutates page text in place, and updates the
   language switcher state.
3. Add a Kuma push monitor for proxy health and DeepL API quota.

DeepL Free: 500k chars/month → covers ~1000 page translations of average wiki
articles. Beyond that, DeepL Pro at €5.49/M chars or Google Translate API at
$20/M chars.

## Why not a MediaWiki extension?

`Translate` extension (used by translatewiki.net) requires a translator
community to populate translation units. p2pwiki has zero. The agent eval in
TASK-MEDIUM.13 ruled it out before this lighter approach was chosen.
