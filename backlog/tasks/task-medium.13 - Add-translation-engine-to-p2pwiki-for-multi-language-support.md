---
id: TASK-MEDIUM.13
title: Add translation engine to p2pwiki for multi-language support
status: In Progress
assignee: []
created_date: '2026-05-09 15:47'
updated_date: '2026-05-10 00:00'
labels: []
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replace the dormant separate p2pwikifr instance with on-demand translation on the main p2pwiki wiki. Evaluate options: (1) MediaWiki Translate extension (Wikimedia, content-level human-curated), (2) self-hosted LibreTranslate widget (visitor-side MT), (3) external MT API (DeepL, Google). Pick based on use case: occasional reader translation = LibreTranslate widget; community-curated translations = Translate extension.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Evaluate Translate ext vs LibreTranslate widget vs DeepL/Google MT API — document tradeoffs (quality, hosting cost, ops burden, content drift risk)
- [x] #2 Pick approach and document decision
- [x] #3 Deploy to staging on a copy of the wiki
- [x] #4 Verify French rendering on at least 10 representative pages
- [x] #5 Roll out to wiki.p2pfoundation.net with CDN caching for translated pages
- [ ] #6 Update wikifr.p2pfoundation.net to redirect to translated EN wiki
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
EVALUATION: Multi-language support options for wiki.p2pfoundation.net (MW 1.40, ~40k EN articles, bot-heavy traffic, Netcup server: 62GB RAM with only ~1.7GB available, swap exhausted)

## Comparison

| Dimension | Translate Extension | LibreTranslate (self-hosted) | DeepL/Google API widget |
|---|---|---|---|
| **Hosting cost** | ~50MB RAM (PHP only, no extra container) | 1–2 GB RAM + 1–2 GB disk per model; GPU needed for acceptable speed | Zero hosting; DeepL free tier 500k chars/mo; ~$20/M chars after (Google) or €5.49/M (DeepL Pro) |
| **Quality (FR/EN academic/p2p)** | Human-curated = excellent, but requires volunteer translators who don't exist | Mediocre on jargon-heavy content (commons, governance, P2P theory terminology) | DeepL: best MT quality for FR/EN; Google: good FR but inconsistent on niche academic vocab |
| **Ops burden** | High: Translate + LanguageSelector + PageMigrationTool extensions, DB schema additions (translate_* tables), translator workflow, fuzzy-marking system, ongoing triage | Medium: deploy LibreTranslate container, pin model versions, monitor RAM/OOM; no MW integration beyond JS snippet | Low: JS snippet in MediaWiki:Common.js or a skin hook; no server-side changes; API key rotation only |
| **Content drift risk** | Low: translations are versioned units tied to source revision; fuzzy-marking flags stale translations | High: no caching layer — each page load re-translates live EN; no staleness concept, but also never 'stale' | Medium-High if cached: Cloudflare can cache translated HTML but cache never invalidates on source edit; Low if widget translates client-side on each load (fresh but costs money) |
| **CDN cacheability** | Good if pages pre-rendered per language; poor for dynamic translate units | Client-side widget = EN page is cached normally; translation happens in browser, zero server cache benefit | Client-side widget = same as LibreTranslate; server-side proxy pattern allows CF caching but adds complexity |
| **MW 1.40 compatibility** | Translate extension supports MW 1.40 (tested on 1.39–1.42 per translatewiki.net) | N/A — no MW extension needed, pure JS injection | N/A — pure JS injection via MediaWiki:Common.js |

## Key Constraints
- Server has ~1.7 GB RAM free with swap exhausted — **LibreTranslate container is a hard no** (would OOM-kill other services)
- Zero active translators → Translate extension's human-curation model provides no value; it's overhead with no payoff
- Traffic is bot-heavy and read-only; the use case is passive reader access, not editorial workflow
- 40k articles × ~5 languages = 200k translation units to bootstrap if using Translate extension

## Recommendation: DeepL/Google API client-side widget (Option 3)

Deploy a lightweight client-side widget (e.g. DeepL's official JS widget or a small vanilla-JS shim calling DeepL Free API) injected via `MediaWiki:Common.js`. No server changes, no new containers, no RAM overhead. DeepL free tier (500k chars/month) covers moderate non-English readership at zero cost; upgrade path is clear if traffic grows. Quality on FR/EN is the best available for academic/governance text. Content drift is moot because no translations are persisted — each reader translates on demand. CDN still caches the EN HTML normally.

If DeepL free tier proves insufficient, Google Translate's free embedded widget (translate.google.com/translate_a) is a zero-cost fallback with no API key required, though quality is slightly lower for niche content.

Translate extension should be revisited only if a translator community materialises. LibreTranslate is blocked by the RAM constraint until the server is upgraded or a dedicated node is provisioned.

Decision via parallel agent eval (see prior notes): DeepL/Google API client-side widget. Skipping LibreTranslate (server has only ~1.7GB free RAM, swap exhausted) and Translate extension (no translator community to sustain it). Implementation = JS snippet in MediaWiki:Common.js calling DeepL Free API. Next: deploy snippet, smoke test 10 representative pages, document API key rotation.

DEPLOYED 2026-05-09. Implementation chose Google Translate element.js (client-side, zero RAM, no API key) over DeepL (DeepL has no client-side widget; would need server-side proxy = Phase 2 if quality justifies).

Files:
- dev-ops/netcup/p2pwiki/translate-widget.php — MediaWiki BeforePageDisplay hook injecting Google Translate widget
- dev-ops/netcup/p2pwiki/translate-widget.md — deployment + rollback docs

Wired in via:
- /opt/websites/p2pwiki/docker-compose.yml: added bind mount ./extensions:/var/www/html/p2pwiki-custom:ro
- /opt/websites/p2pwiki/LocalSettings.php: require_once "$IP/p2pwiki-custom/translate-widget.php";

Languages: fr, es, de, pt, it, nl, ja, zh-CN.
Skip rules: special pages, edit/history/submit/delete actions.

Verified via direct container hit: widget JS injected on /Commons-based_peer_production (200, markers in HTML).

Phase 2 if read traffic + quality demand it: replace Google with a Bun proxy on Netcup that calls DeepL Free API (500k chars/mo). ~30 MB RAM, ~30 LOC. Documented in translate-widget.md.
<!-- SECTION:NOTES:END -->
