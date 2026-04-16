#!/bin/bash
# enforce-container-limits.sh — Ensures all Docker containers have memory/CPU limits
# Runs every 5 minutes via cron. Catches new containers, restarts, recomposes.
# Log: /var/log/docker-limits.log

set -uo pipefail

LOG="/var/log/docker-limits.log"
APPLIED=0

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"; }

# ── Tier assignments ──
# Returns "MEMORY CPUS" or exits 1 to skip
get_tier() {
    local name="$1"

    # ── SKIP: managed by compose or intentionally large ──
    case "$name" in
        # rspace-online stack (compose-managed)
        rspace-online|rspace-db|encryptid|encryptid-db|scribus-novnc) return 1 ;;
        open-notebook|open-notebook-cca|open-notebook-votc) return 1 ;;
        blender-worker|blender-api|kicad-mcp|freecad-mcp) return 1 ;;
        meeting-intelligence-transcriber|whisper-local|docling-service) return 1 ;;
        ollama) return 1 ;;
        openrouteservice) return 1 ;;
        cyclos|cyclos-db) return 1 ;;
        hcc-api|hcc-mem-staging|db-backup-cron) return 1 ;;
        infisical) return 1 ;;
        immich_machine_learning|immich_postgres) return 1 ;;
        open-claw-iron-ironclaw-1|open-claw-iron-postgres-1) return 1 ;;
        p2pwiki-ai|p2pwiki-db|p2pwiki-elasticsearch) return 1 ;;
        postiz-cc) return 1 ;;
        rdesign-api|rdesign-frontend|rdesign-studio) return 1 ;;
        semantic-search-api|semantic-search-embedding|semantic-search-qdrant) return 1 ;;
        temporal-shared-elasticsearch) return 1 ;;
        traefik) return 1 ;;
        voice-command-api) return 1 ;;
        twenty-cl-db|twenty-cl-redis|twenty-cl-server|twenty-cl-worker) return 1 ;;
        twenty-cc-server|twenty-cc-worker|twenty-ch-server|twenty-ch-worker) return 1 ;;
        twenty-rn-server|twenty-rn-worker|twenty-server-1|twenty-worker-1) return 1 ;;
        twenty-votc-server|twenty-votc-worker) return 1 ;;
        app) return 1 ;;
        meeting-intelligence-api) return 1 ;;
    esac

    # ── XLARGE: 2g / 2 CPUs ──
    case "$name" in
        immich_server|rphotos_machine_learning|erpnext-backend) echo "2g 2"; return 0 ;;
    esac

    # ── LARGE: 1g / 1-2 CPUs ──
    case "$name" in
        gitea|jellyfin|n8n|n8n-cosmolocal|mattermost) echo "1g 2"; return 0 ;;
        jeffsi-meet-jvb-1|dko-backend|seafile|rphotos_server) echo "1g 2"; return 0 ;;
        meeting-intelligence-jibri|receipt-wrangler|rfiles-api|rfiles-celery-worker) echo "1g 1"; return 0 ;;
        clip-forge-backend-1|clip-forge-worker-1|jellyseerr|slskd) echo "1g 1"; return 0 ;;
        rory-os) echo "1g 1"; return 0 ;;
    esac

    # ── MEDIUM: 512m / 1 CPU ──
    case "$name" in
        affine_server|ghost-cosmolocal|ghost-crypto-commons|navidrome) echo "512m 1"; return 0 ;;
        docmost|docmost-cl|ccg-website|cca-website|listmonk|uptime-kuma|umami) echo "512m 1"; return 0 ;;
        cloudflared|deploy-webhook|syncthing|headscale) echo "512m 1"; return 0 ;;
        p2p-blog|p2p-blogfr|p2p-bloggr|p2p-blognl|p2p-web|p2p-wiki|p2pwiki|p2pwikifr) echo "512m 1"; return 0 ;;
        mailcowdockerized-mysql-mailcow-1|mailcowdockerized-clamd-mailcow-1) echo "512m 1"; return 0 ;;
        mailcowdockerized-rspamd-mailcow-1|mailcowdockerized-sogo-mailcow-1) echo "512m 1"; return 0 ;;
        mailcowdockerized-dovecot-mailcow-1|mailcowdockerized-php-fpm-mailcow-1) echo "512m 1"; return 0 ;;
        erpnext-mariadb|erpnext-frontend|payment-hyperswitch|katheryn-cms) echo "512m 1"; return 0 ;;
        opencode|qbittorrent|transmission|pkmn-graph|ai-orchestrator) echo "512m 1"; return 0 ;;
        mycrozine-web|email-relay|rinbox-online-app-1|rinbox-online-sync-worker-1) echo "512m 1"; return 0 ;;
    esac

    # ── SMALL: 256m / 0.5 CPU ──
    # Match common patterns for DBs, redis, and small services
    case "$name" in
        *-db|*-postgres|*_postgres|*-redis|*_redis|*-cache|*-memcached) echo "256m 0.5"; return 0 ;;
    esac
    case "$name" in
        # Explicit small services
        encryptid-up-service|headplane|flipbook-service|pdf-ocr|erowid-bot) echo "256m 0.5"; return 0 ;;
        archive-worker|filebrowser|claude-mail-agent|upload-service|wizarr) echo "256m 0.5"; return 0 ;;
        prowlarr|radarr|sonarr|lidarr|epg|threadfin) echo "256m 0.5"; return 0 ;;
        rtrips-online|rbooks-online|rauctions-online|rcal-online|rcart|rcart-online) echo "256m 0.5"; return 0 ;;
        rchats|revents-online|rforum-online|rinbox|rinbox-sync|rinbox-ws) echo "256m 0.5"; return 0 ;;
        rinbox-online-ws-1|rnotes-frontend|rmaps-online|rmaps-sync) echo "256m 0.5"; return 0 ;;
        rwallet-online|rspace_registry|rswag-backend|rswag-frontend|rtasks) echo "256m 0.5"; return 0 ;;
        rtube|rtube-archive|votc|defectfi|defectfi-relay|newsletter-api|newsletter-sync) echo "256m 0.5"; return 0 ;;
        schedule-jeffemmett|cal-jeffemmett|zoomcal-jeffemmett) echo "256m 0.5"; return 0 ;;
        payment-onramp|payment-offramp|payment-commerce|payment-consensus) echo "256m 0.5"; return 0 ;;
        payment-curve|payment-flow|payment-relay|payment-treasury|payment-wallet) echo "256m 0.5"; return 0 ;;
        provider-registry|yield-vault-backend|rfiles-celery-beat) echo "256m 0.5"; return 0 ;;
        postiz-cc-temporal|postiz-p2pf-temporal|postiz-temporal|temporal-shared-ui) echo "256m 0.5"; return 0 ;;
        erpnext-queue-short|erpnext-scheduler|erpnext-websocket) echo "256m 0.5"; return 0 ;;
        jeffsi-meet-jicofo-1|jeffsi-meet-prosody-1|jeffsi-meet-web-1|jeffsi-coturn) echo "256m 0.5"; return 0 ;;
        soulsync|soulsync-dl|soulsync-player|boredom-ws|youtube-transcriber) echo "256m 0.5"; return 0 ;;
        immich_power_tools|immich_heatmap|games-backend|games-worker) echo "256m 0.5"; return 0 ;;
        jami-opendht|rnetwork-graph|rphotos_provision) echo "256m 0.5"; return 0 ;;
        clip-forge-frontend-1|clipforge-wg|fzf-fuzzy-flights) echo "256m 0.5"; return 0 ;;
    esac

    # ── MICRO: 128m / 0.25 CPU — static sites, landing pages, cron, watchers ──
    case "$name" in
        # Mailcow small services
        mailcowdockerized-*) echo "128m 0.25"; return 0 ;;
        # Cron/watchers
        schedule-cron|folder-watcher|kuma-alert-agent|sablier) echo "128m 0.25"; return 0 ;;
        backlog-aggregator|backlog-reply-handler|rtasks-aggregator) echo "128m 0.25"; return 0 ;;
        # Static sites / tiny apps (catch-all patterns)
        *-prod) echo "128m 0.25"; return 0 ;;
        *-staging) echo "128m 0.25"; return 0 ;;
        *-landing) echo "128m 0.25"; return 0 ;;
    esac
    case "$name" in
        # Explicit micro containers
        canvas-website|canvas-dev|personal-site|personal-dashboard|phomemo-label-tool) echo "128m 0.25"; return 0 ;;
        r2-mount|video-player|video360-splitter|nginx-rtmp|rtube-rtmp) echo "128m 0.25"; return 0 ;;
        jefflix|jefflix-dns|games-frontend|games-nginx|seafile-memcached) echo "128m 0.25"; return 0 ;;
        ridentity_landing|rmail_landing|rphotos_landing|rpubs|rsocials|rsocials-online) echo "128m 0.25"; return 0 ;;
        rswag-landing|rspace-widgets|rtasks|fake-license|elle-o-elle|the-last-draw) echo "128m 0.25"; return 0 ;;
        conviction-voting-demo|conviction-voting-prod|cosmolocal-website|mycocivics) echo "128m 0.25"; return 0 ;;
        mycofi-earth-website|mycopunk-prod|mycostack-website|innernet-lol) echo "128m 0.25"; return 0 ;;
        cineasthesia-home|cineasthesia-landing|gaia-ar|decolonize-time) echo "128m 0.25"; return 0 ;;
        cynthia-poetry|lunar-calendar|littlehive-shop|flight-club-lol) echo "128m 0.25"; return 0 ;;
        fungiflows|worldplay-website|xhivart-mirror|katheryn-frontend) echo "128m 0.25"; return 0 ;;
    esac

    # Catch compose-generated long names (website-*, online-*)
    case "$name" in
        *-website-*|*-online-*|*-deck-*|*-network-*|*-funding-*|*-quest-*|*-travel-*) echo "128m 0.25"; return 0 ;;
    esac

    # ── DEFAULT: small (256m / 0.5 CPU) for anything unmatched ──
    echo "256m 0.5"
    return 0
}

# ── Main loop ──
for cid in $(docker ps -q 2>/dev/null); do
    info=$(docker inspect --format '{{.Name}} {{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' "$cid" 2>/dev/null) || continue
    name="${info%% *}"
    name="${name#/}"
    mem=$(echo "$info" | awk '{print $2}')
    cpus=$(echo "$info" | awk '{print $3}')

    # Skip only if BOTH memory AND CPU limits are already set
    [[ "$mem" != "0" && "$cpus" != "0" ]] && continue

    tier=$(get_tier "$name") || continue
    target_mem=$(echo "$tier" | awk '{print $1}')
    target_cpus=$(echo "$tier" | awk '{print $2}')

    if docker update --memory="$target_mem" --memory-swap="$target_mem" --cpus="$target_cpus" "$name" >/dev/null 2>&1; then
        log "ENFORCE $name → ${target_mem} / ${target_cpus} CPUs"
        APPLIED=$((APPLIED + 1))
    else
        log "FAIL $name → ${target_mem} / ${target_cpus} CPUs"
    fi
done

[[ $APPLIED -gt 0 ]] && log "Applied limits to $APPLIED container(s)"
