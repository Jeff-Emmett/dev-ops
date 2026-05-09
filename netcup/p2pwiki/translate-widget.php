<?php
/**
 * Multilingual translation widget for wiki.p2pfoundation.net (TASK-MEDIUM.13).
 *
 * Replaces the deprecated separate p2pwikifr instance (retired 2026-05-09 — see
 * TASK-MEDIUM.14) with on-demand client-side Google Translate. Zero server-side
 * resources, no API keys, no DB changes. Translates on browser, cached normally
 * by Cloudflare for the EN source pages.
 *
 * Languages are scoped to p2pfoundation's known reader base: FR (primary, from
 * wikifr deprecation), ES, DE, PT, IT, NL (matches p2p-blognl audience).
 *
 * Quality: Google MT is mediocre on niche commons/governance vocabulary. If
 * traffic justifies it, swap for a DeepL proxy (server-side Pro API call, key
 * hidden behind a small Netcup-hosted proxy). Tracked as Phase 2 in the task.
 *
 * Deployment: require_once this file from LocalSettings.php at the bottom:
 *   require_once "$IP/extensions/translate-widget.php";
 * Or copy this file's contents directly into LocalSettings.php.
 *
 * Cache invalidation: the widget injects the same script on every page load,
 * so MediaWiki's parser cache is unaffected. To remove the widget, delete or
 * comment out this file's `require_once` and the next page load is clean.
 */

if ( !defined( 'MEDIAWIKI' ) ) {
    die( 'This file is part of MediaWiki and is not a valid entry point.' );
}

$wgHooks['BeforePageDisplay'][] = function ( OutputPage $out, Skin $skin ) {
    // Skip on edit/history/admin pages — translation makes them confusing
    $title = $out->getTitle();
    if ( !$title ) return;
    if ( $title->isSpecialPage() ) return;
    if ( in_array( $out->getRequest()->getRawVal( 'action' ), [ 'edit', 'history', 'submit', 'delete' ], true ) ) return;

    $js = <<<'JS'
(function() {
  if (window.__p2pTranslateInjected) return;
  window.__p2pTranslateInjected = true;

  var widget = document.createElement('div');
  widget.id = 'google_translate_element';
  widget.style.cssText = [
    'position:fixed', 'top:10px', 'right:10px', 'z-index:9999',
    'background:#fff', 'padding:6px 8px', 'border-radius:4px',
    'box-shadow:0 2px 6px rgba(0,0,0,0.18)', 'font-size:12px'
  ].join(';');

  function inject() {
    document.body.appendChild(widget);
    var s = document.createElement('script');
    s.src = '//translate.google.com/translate_a/element.js?cb=p2pTranslateInit';
    document.body.appendChild(s);
  }

  window.p2pTranslateInit = function() {
    new google.translate.TranslateElement({
      pageLanguage: 'en',
      includedLanguages: 'fr,es,de,pt,it,nl,ja,zh-CN',
      layout: google.translate.TranslateElement.InlineLayout.SIMPLE,
      autoDisplay: false
    }, 'google_translate_element');
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', inject);
  } else {
    inject();
  }
})();
JS;

    $out->addInlineScript( $js );
};
