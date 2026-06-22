#!/bin/bash
# enforce-container-limits.sh — Ensures all Docker containers have memory/CPU limits
# Runs every 5 minutes via cron. Catches new containers, restarts, recomposes.
# Log: /var/log/docker-limits.log
# Re-enabled 2026-05-30 with corrected tiers + GITEA-ACTIONS-TASK-* SKIP fix

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
        # Gitea CI runner job containers (ephemeral, can need 1g+ for builds — root cause of 2026-05-11 disable)
        GITEA-ACTIONS-TASK-*) return 1 ;;
        # Gitea itself: compose mem_limit=3g, live=3g — skip to avoid regressing
        gitea) return 1 ;;
        claude-dev) return 1 ;;  # 2026-06-02 interactive dev box, compose 6g/4cpu — never cap; 256m OOM killed mosh tmux
        # rspace-online stack (compose-managed)
        rspace-online|rspace-online-dev|rspace-db|rspace-db-dev|rspace-zk-staging|rspace-zk-staging-db|encryptid|encryptid-db|scribus-novnc|compute-courier|rserver|reticulum) return 1 ;;
        # 2026-06-22: image-forge compose sets 1500M for Inkscape vector renders
        # (GTK + cairo surface). DEFAULT 256m would OOM-kill a real render.
        # Sablier scale-to-zero already frees the RAM when idle. Compose owns it.
        image-forge) return 1 ;;
        # 2026-06-22: Penpot stack — compose sets per-service mem_limits (backend
        # JVM 1200m etc); DEFAULT 256m would OOM the backend. Sablier scale-to-
        # zero frees it all when idle. Compose owns the limits.
        penpot-*) return 1 ;;
        open-notebook|open-notebook-cca|open-notebook-votc) return 1 ;;
        blender-worker|blender-api|kicad-mcp|freecad-mcp) return 1 ;;
        meeting-intelligence-transcriber|whisper-local|docling-service) return 1 ;;
        ollama) return 1 ;;
        openrouteservice) return 1 ;;
        cyclos|cyclos-db) return 1 ;;
        hcc-api|hcc-mem-staging|db-backup-cron) return 1 ;;
        cadcad-lab) return 1 ;;
        cadcad-mcp) return 1 ;;
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
        # 2026-05-10: explicit memory configured via compose mem_limit:4g (p2p-db) and Discourse launcher docker_args:--memory=3g (p2pforum). Skip the *-db glob downgrade.
        p2p-db|p2pforum) return 1 ;;
        # 2026-05-11: p2pwiki bumped to 1g (compose mem_limit) to prevent Apache prefork wedge. Skip MEDIUM-tier downgrade.
        p2pwiki) return 1 ;;
        # Large/transient: rust compiler, Plex, funion sidecar — legitimately need >2g; skip enforcement
        happy_rhodes|jefflix|funion-sidecar|funion-sidecar-*) return 1 ;;
    esac

    # ── XLARGE: 2g / 2 CPUs ──
    case "$name" in
        immich_server|rphotos_machine_learning|erpnext-backend|litellm) echo "2g 2"; return 0 ;;
        navidrome) echo "2g 1"; return 0 ;;
    esac

    # ── LARGE: 1g / 1-2 CPUs ──
    case "$name" in
        n8n|n8n-cosmolocal|mattermost|crowdsec) echo "1g 2"; return 0 ;;
        jeffsi-meet-jvb-1) echo "1536m 2"; return 0 ;;
        dko-backend|seafile|rphotos_server) echo "1g 2"; return 0 ;;
        p2p-blog|p2p-blogfr|p2p-bloggr|p2p-blognl) echo "2g 2"; return 0 ;;
        p2p-web) echo "1g 1"; return 0 ;;
        deploy-webhook) echo "1g 1"; return 0 ;;
        uptime-kuma) echo "1g 1"; return 0 ;;
        qbittorrent) echo "1g 1"; return 0 ;;
        meeting-intelligence-jibri|receipt-wrangler|rfiles-api|rfiles-celery-worker) echo "1g 1"; return 0 ;;
        clip-forge-backend-1|clip-forge-worker-1|jellyseerr|slskd) echo "1g 1"; return 0 ;;
        rory-os) echo "1g 1"; return 0 ;;
        # Hand-bumped at live=1g — preserve
        katheryn-frontend|forgejo-peer) echo "1g 1"; return 0 ;;
    esac

    # ── XLARGE+: 3g ──
    case "$name" in
        postiz-p2pf) echo "3g 1"; return 0 ;;
    esac

    # ── MEDIUM: 512m / 1 CPU ──
    case "$name" in
        engine-pool-redis) echo "512m 1"; return 0 ;;
        affine_server|ghost-cosmolocal|ghost-crypto-commons) echo "512m 1"; return 0 ;;
        ghost-cosmolocal-db) echo "512m 1"; return 0 ;;
        docmost|ccg-website|cca-website|listmonk|umami) echo "512m 1"; return 0 ;;
        cloudflared|syncthing) echo "512m 1"; return 0 ;;
        mailcowdockerized-mysql-mailcow-1|mailcowdockerized-clamd-mailcow-1) echo "512m 1"; return 0 ;;
        mailcowdockerized-rspamd-mailcow-1|mailcowdockerized-sogo-mailcow-1) echo "512m 1"; return 0 ;;
        mailcowdockerized-dovecot-mailcow-1|mailcowdockerized-php-fpm-mailcow-1) echo "512m 1"; return 0 ;;
        erpnext-mariadb|erpnext-frontend|payment-hyperswitch|katheryn-cms) echo "512m 1"; return 0 ;;
        transmission|pkmn-graph|ai-orchestrator) echo "512m 1"; return 0 ;;
        mycrozine-web|email-relay|rinbox-online-app-1|rinbox-online-sync-worker-1) echo "512m 1"; return 0 ;;
        # Hand-bumped at live=512m — preserve
        mailcowdockerized-ofelia-mailcow-1|wizarr|soulsync|searxng) echo "512m 1"; return 0 ;;
    esac

    # ── MEDIUM-HIGH: 768m / 1 CPU ──
    case "$name" in
        mermaid-animator|commons-hub-web|doc-forge|docmost-cl|docmost-voc|opencode) echo "768m 1"; return 0 ;;
        ghost-crypto-commons-db) echo "384m 0.5"; return 0 ;;
    esac

    # ── MEDIUM-DB: 384m / 0.5 CPU — dbs/services that OOM at 256m ──
    case "$name" in
        gitea-db) echo "384m 0.5"; return 0 ;;
        radarr|lidarr|prowlarr|sonarr) echo "384m 0.5"; return 0 ;;
        engine-pool-server|litellm-db|pkmn-db) echo "384m 0.5"; return 0 ;;
        collab-server-collab-mongo-1|temporal-shared-postgres) echo "384m 0.5"; return 0 ;;
        nla-oracle|headplane|rphotos_postgres) echo "384m 0.5"; return 0 ;;
        rinbox-ws|rmesh-holonserve) echo "384m 0.5"; return 0 ;;
    esac

    # ── SMALL: 256m / 0.5 CPU ──
    # Match common patterns for DBs, redis, and small services
    case "$name" in
        *-db|*-postgres|*_postgres|*-redis|*_redis|*-cache|*-memcached) echo "256m 0.5"; return 0 ;;
    esac
    case "$name" in
        # Explicit small services
        encryptid-up-service|flipbook-service|pdf-ocr|erowid-bot) echo "256m 0.5"; return 0 ;;
        archive-worker|filebrowser|claude-mail-agent|upload-service) echo "256m 0.5"; return 0 ;;
        headscale) echo "256m 0.5"; return 0 ;;
        prowlarr|radarr|sonarr|lidarr|epg|threadfin) echo "256m 0.5"; return 0 ;;
        rtrips-online|rbooks-online|rauctions-online|rcal-online|rcart|rcart-online) echo "256m 0.5"; return 0 ;;
        rchats|revents-online|rforum-online|rinbox|rinbox-sync) echo "256m 0.5"; return 0 ;;
        rnotes-frontend|rmaps-online|rmaps-sync) echo "256m 0.5"; return 0 ;;
        rwallet-online|rspace_registry|rswag-backend|rswag-frontend|rtasks) echo "256m 0.5"; return 0 ;;
        rtube|rtube-archive|votc|defectfi|defectfi-relay|newsletter-api|newsletter-sync) echo "256m 0.5"; return 0 ;;
        schedule-jeffemmett|cal-jeffemmett|zoomcal-jeffemmett) echo "256m 0.5"; return 0 ;;
        payment-onramp|payment-offramp|payment-commerce|payment-consensus) echo "256m 0.5"; return 0 ;;
        payment-curve|payment-flow|payment-relay|payment-treasury|payment-wallet) echo "256m 0.5"; return 0 ;;
        provider-registry|yield-vault-backend|rfiles-celery-beat) echo "256m 0.5"; return 0 ;;
        postiz-cc-temporal|postiz-p2pf-temporal|postiz-temporal|temporal-shared-ui) echo "256m 0.5"; return 0 ;;
        erpnext-queue-short|erpnext-scheduler|erpnext-websocket) echo "256m 0.5"; return 0 ;;
        jeffsi-meet-jicofo-1|jeffsi-meet-prosody-1|jeffsi-meet-web-1|jeffsi-coturn) echo "256m 0.5"; return 0 ;;
        soulsync-dl|soulsync-player|boredom-ws|youtube-transcriber) echo "256m 0.5"; return 0 ;;
        immich_power_tools|immich_heatmap|games-backend|games-worker) echo "256m 0.5"; return 0 ;;
        jami-opendht|rnetwork-graph|rphotos_provision) echo "256m 0.5"; return 0 ;;
        clip-forge-frontend-1|clipforge-wg|fzf-fuzzy-flights) echo "256m 0.5"; return 0 ;;
        # Hand-bumped at live=256m — preserve
        kuma-alert-agent) echo "256m 0.5"; return 0 ;;
        # Bumped from micro: confirmed needs 256m
        alertbay-prod|video-player|backlog-aggregator|books-website-books-website-1) echo "256m 0.5"; return 0 ;;
        pkmn-celery-worker) echo "1536m 1"; return 0 ;;
    esac

    # ── MICRO: 128m / 0.25 CPU — static sites, landing pages, cron, watchers ──
    case "$name" in
        # Mailcow small services
        mailcowdockerized-*) echo "128m 0.25"; return 0 ;;
        # Cron/watchers
        schedule-cron|folder-watcher|sablier) echo "128m 0.25"; return 0 ;;
        rtasks-aggregator|backlog-reply-handler) echo "128m 0.25"; return 0 ;;
        # Static sites / tiny apps (catch-all patterns)
        *-prod) echo "128m 0.25"; return 0 ;;
        *-staging) echo "128m 0.25"; return 0 ;;
        *-landing) echo "128m 0.25"; return 0 ;;
    esac
    case "$name" in
        # Explicit micro containers
        canvas-website|canvas-dev|personal-site|personal-dashboard|phomemo-label-tool) echo "128m 0.25"; return 0 ;;
        r2-mount|video360-splitter|nginx-rtmp|rtube-rtmp) echo "128m 0.25"; return 0 ;;
        jefflix-dns|games-frontend|games-nginx|seafile-memcached) echo "128m 0.25"; return 0 ;;
        ridentity_landing|rmail_landing|rphotos_landing|rpubs|rsocials|rsocials-online) echo "128m 0.25"; return 0 ;;
        rswag-landing|rspace-widgets|fake-license|elle-o-elle|the-last-draw) echo "128m 0.25"; return 0 ;;
        conviction-voting-demo|cosmolocal-website|mycocivics) echo "128m 0.25"; return 0 ;;
        mycofi-earth-website|mycopunk-prod|mycostack-website|innernet-lol) echo "128m 0.25"; return 0 ;;
        cineasthesia-home|cineasthesia-landing|gaia-ar|decolonize-time) echo "128m 0.25"; return 0 ;;
        cynthia-poetry|lunar-calendar|littlehive-shop|flight-club-lol) echo "128m 0.25"; return 0 ;;
        fungiflows|xhivart-mirror) echo "128m 0.25"; return 0 ;;
    esac
    # ── SMALL: 256m / 0.5 CPU — bumped from MICRO for traffic capacity ──
    case "$name" in
        worldplay-website) echo "256m 0.5"; return 0 ;;
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

    tier=$(get_tier "$name") || continue
    target_mem=$(echo "$tier" | awk '{print $1}')
    target_cpus=$(echo "$tier" | awk '{print $2}')

    # Convert target to bytes/nanocpus for comparison; skip if already exactly matching.
    # This makes the script truly enforce (not merely initialise) without re-applying every cycle.
    target_mem_bytes=$(numfmt --from=iec "${target_mem^^}" 2>/dev/null || echo 0)
    target_cpus_nano=$(awk -v c="$target_cpus" 'BEGIN { printf "%d", c * 1e9 }')
    [[ "$mem" == "$target_mem_bytes" && "$cpus" == "$target_cpus_nano" ]] && continue

    if docker update --memory="$target_mem" --memory-swap="$target_mem" --cpus="$target_cpus" "$name" >/dev/null 2>&1; then
        log "ENFORCE $name → ${target_mem} / ${target_cpus} CPUs"
        APPLIED=$((APPLIED + 1))
    else
        log "FAIL $name → ${target_mem} / ${target_cpus} CPUs"
    fi
done

[[ $APPLIED -gt 0 ]] && log "Applied limits to $APPLIED container(s)"
