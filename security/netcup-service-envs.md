# Netcup service .env index

Auto-generated 2026-05-15 during TASK-88 Phase 3. Lists every
`.env` file on Netcup under `/opt/`, classified by whether it
uses Infisical bootstrap or plain secrets. KEY NAMES ONLY — no
values. Regenerate with `dev-ops/security/dump-netcup-envs.sh`.

Entries in `secrets-inventory.yaml` carry the rotation cadence;
this doc carries the structural overview.

| Path | Type | Keys |
|------|------|------|
| `/opt/ai-orchestrator/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_PROJECT_SLUG,INFISICAL_SEC...` |
| `/opt/apps/affine/.env` | plain | `DB_DATA_LOCATION,UPLOAD_LOCATION,CONFIG_LOCATION,DB_USERNAME,DB_PASSWORD,DB_DATA...` |
| `/opt/apps/ai-audit/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,DEEP_SCAN,LITELLM_MASTER_KEY` |
| `/opt/apps/atproto-bridge/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/apps/atproto-pds/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/apps/b-prize-live/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/apps/backlog-md/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/apps/backlog-reply-handler/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_PROJECT_SLUG,INFISICAL_URL...` |
| `/opt/apps/cadcad-lab/.env` | plain | `JUPYTER_TOKEN` |
| `/opt/apps/cineasthesia-landing/.env` | plain | `SMTP_USER,SMTP_PASS,SMTP_FROM` |
| `/opt/apps/claude-mail-agent/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_PROJECT_SLUG,INFISICAL_URL...` |
| `/opt/apps/commons-hub-app.bak.before-directus-auth-1778217813/.env` | plain | `NEXT_PUBLIC_SUPABASE_URL,NEXT_PUBLIC_SUPABASE_ANON_KEY,SUPABASE_SERVICE_ROLE_KEY...` |
| `/opt/apps/commons-hub-app/.env` | plain | `NEXT_PUBLIC_SUPABASE_URL,SUPABASE_INTERNAL_URL,NEXT_PUBLIC_SUPABASE_ANON_KEY,SUP...` |
| `/opt/apps/commons-hub-directus/.env` | plain | `KEY,SECRET,DB_CLIENT,DB_HOST,DB_PORT,DB_DATABASE,DB_USER,DB_PASSWORD,DB_SSL,ADMI...` |
| `/opt/apps/cyclos/.env` | plain | `CYCLOS_DB_PASSWORD,COMPOSE_FILE` |
| `/opt/apps/db-backup.zombie-2026-05-09/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_PROJECT_SLUG` |
| `/opt/apps/defectfi/.env` | plain | `SMTP_HOST,SMTP_PORT,SMTP_USER,SMTP_PASS,FOXSONG_DEN_TOKEN,DEFECTFI_SAFE_ADDRESS` |
| `/opt/apps/docmost/.env` | plain | `DOCMOST_APP_SECRET,DOCMOST_CL_APP_SECRET,DOCMOST_CL_SMTP_PASSWORD,DOCMOST_SMTP_P...` |
| `/opt/apps/draw-fast/.env` | plain | `FAL_KEY` |
| `/opt/apps/email-relay/.env` | plain | `SMTP_HOST,SMTP_PORT,SMTP_USER,SMTP_PASS,SMTP_FROM,EMAIL_RELAY_API_KEY,CONTACT_AL...` |
| `/opt/apps/encryptid-up-service/.env` | plain | `RELAY_PRIVATE_KEY,JWT_SECRET,PORT,CHAIN_ID,RPC_URL,ENCRYPTID_URL` |
| `/opt/apps/erowid-bot/.env` | plain | `DATABASE_URL,DATABASE_URL_SYNC,POSTGRES_USER,POSTGRES_PASSWORD,POSTGRES_DB,LLM_P...` |
| `/opt/apps/falkordb/.env` | plain | `FALKORDB_PASSWORD` |
| `/opt/apps/funion-sidecar/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_PROJECT_SLUG,INFISICAL_ENV` |
| `/opt/apps/games-platform/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,DB_PASSWORD,VITE_API_URL,DOMAIN` |
| `/opt/apps/ghost-crypto-commons/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,MYSQL_ROOT_PASSWORD,MYSQL_PASSWORD` |
| `/opt/apps/grid-trading-bot/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_PROJECT_SLUG,POSTGRES_PASS...` |
| `/opt/apps/headscale-deploy/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,HEADPLANE_BASIC_AUTH` |
| `/opt/apps/heart-beat/.env` | plain | `SMTP_PASS` |
| `/opt/apps/kuma-alert-agent/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_PROJECT_SLUG,INFISICAL_URL...` |
| `/opt/apps/listmonk/.env` | plain | `LISTMONK_DB_PASSWORD` |
| `/opt/apps/litellm/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,POSTGRES_PASSWORD,FUNION_SIDECAR_TOK...` |
| `/opt/apps/mattermost/.env` | plain | `POSTGRES_PASSWORD` |
| `/opt/apps/natural-language-agreements/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/apps/open-claw-iron/.env` | mixed (Infisical + plain) | `POSTGRES_PASSWORD,DATABASE_POOL_SIZE,LLM_BACKEND,LLM_BASE_URL,LLM_MODEL,GATEWAY_...` |
| `/opt/apps/p2pwiki-ai/.env` | plain | `OLLAMA_BASE_URL,OLLAMA_MODEL,ANTHROPIC_API_KEY,USE_CLAUDE_FOR_DRAFTS,USE_OLLAMA_...` |
| `/opt/apps/payment-infra/.env` | mixed (Infisical + plain) | `NODE_ENV,LOG_LEVEL,DB_USER,DB_PASSWORD,DB_NAME,DB_PORT,REDIS_URL,REDIS_PORT,BASE...` |
| `/opt/apps/pentagi/.env` | mixed (Infisical + plain) | `ANTHROPIC_API_KEY,ANTHROPIC_SERVER_URL,OLLAMA_SERVER_URL,DUCKDUCKGO_ENABLED,COOK...` |
| `/opt/apps/pkmn/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,DB_PASSWORD,REDIS_PASSWORD,GOOGLE_CL...` |
| `/opt/apps/postiz-votc/.env` | plain | `VOTC_POSTGRES_PASSWORD,VOTC_JWT_SECRET,EMAIL_PASS` |
| `/opt/apps/postiz/.env` | plain | `JWT_SECRET,POSTGRES_PASSWORD,LISTMONK_DOMAIN,LISTMONK_USER,LISTMONK_API_KEY,LIST...` |
| `/opt/apps/rNetwork-online/.env` | plain | `TWENTY_API_URL,TWENTY_FCDM_API_KEY,TWENTY_COSMOLOCAL_API_KEY,PORT,HOST,STORAGE_D...` |
| `/opt/apps/rcal-online/.env` | plain | `POSTGRES_PASSWORD,DATABASE_URL,NEXT_TELEMETRY_DISABLED,NEXT_PUBLIC_ENCRYPTID_SER...` |
| `/opt/apps/rchats-online/.env` | mixed (Infisical + plain) | `DB_PASSWORD,INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,ENCRYPTID_DEMO_SPACES,NE...` |
| `/opt/apps/revents-online/.env` | plain | `POSTGRES_PASSWORD,DATABASE_URL,NEXT_TELEMETRY_DISABLED,NEXT_PUBLIC_ENCRYPTID_SER...` |
| `/opt/apps/rfiles-online/.env` | mixed (Infisical + plain) | `DB_PASSWORD,REDIS_PASSWORD,SECRET_KEY,DEBUG,ALLOWED_HOSTS,SHARE_BASE_URL,ENCRYPT...` |
| `/opt/apps/rforum-online/.env` | plain | `ENCRYPTID_DEMO_SPACES` |
| `/opt/apps/rinbox-online/.env` | mixed (Infisical + plain) | `DATABASE_URL,POSTGRES_PASSWORD,REDIS_URL,IMAP_HOST,IMAP_PORT,SMTP_HOST,SMTP_PORT...` |
| `/opt/apps/rmail-online/.env` | mixed (Infisical + plain) | `DATABASE_URL,POSTGRES_PASSWORD,REDIS_URL,IMAP_HOST,IMAP_PORT,SMTP_HOST,SMTP_PORT...` |
| `/opt/apps/rmesh-holonserve/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/apps/rmesh-online/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,DB_PASSWORD` |
| `/opt/apps/rmesh-reticulum/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/apps/rnotes-online/.env` | plain | `DB_PASSWORD,NEXTAUTH_SECRET` |
| `/opt/apps/rory-os/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/apps/rphotos-online/.env` | plain | `UPLOAD_LOCATION,DB_DATA_LOCATION,TZ,IMMICH_VERSION,DB_PASSWORD,DB_USERNAME,DB_DA...` |
| `/opt/apps/rspace-registry/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/apps/rswag/.env` | mixed (Infisical + plain) | `DB_PASSWORD,CORS_ORIGINS,NEXT_PUBLIC_API_URL,POD_SANDBOX_MODE,INFISICAL_CLIENT_I...` |
| `/opt/apps/rtrips-online/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,DB_PASSWORD` |
| `/opt/apps/rtube-online/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/apps/rwork-online/.env` | mixed (Infisical + plain) | `DB_PASSWORD,NEXTAUTH_SECRET,SMTP_HOST,SMTP_PORT,SMTP_USER,SMTP_PASS,INFISICAL_CL...` |
| `/opt/apps/schedule-jeffemmett/.env` | plain | `POSTGRES_PASSWORD,ADMIN_PASSWORD,SESSION_SECRET,GOOGLE_CLIENT_ID,GOOGLE_CLIENT_S...` |
| `/opt/apps/seafile-deploy/.env` | plain | `SEAFILE_DB_ROOT_PASS,SEAFILE_ADMIN_EMAIL,SEAFILE_ADMIN_PASS` |
| `/opt/apps/settlement-rs/.env` | plain | `RUST_LOG,HS_MERCHANT_SECRET_KEY,HS_WEBHOOK_SHARED_SECRET,HS_BASE_URL,RSPACE_INTE...` |
| `/opt/apps/soulsync-dl/.env` | plain | `NAVIDROME_USER,NAVIDROME_PASS,WATCHED_PLAYLISTS,POLL_INTERVAL,LASTFM_API_KEY` |
| `/opt/apps/spore-commons/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_PROJECT_SLUG,POSTGRES_PASS...` |
| `/opt/apps/trust-engine-rs/.env` | plain | `ENCRYPTID_DB_PASSWORD,INTERNAL_API_KEY,WEBHOOK_INTERNAL_URL,RUST_LOG,DATABASE_UR...` |
| `/opt/apps/twenty-cc/.env` | plain | `TAG,PG_DATABASE_PASSWORD,SERVER_URL,APP_SECRET,STORAGE_TYPE,EMAIL_FROM_ADDRESS,E...` |
| `/opt/apps/twenty-cosmolocal/.env` | plain | `TAG,PG_DATABASE_PASSWORD,SERVER_URL,APP_SECRET,STORAGE_TYPE,EMAIL_FROM_ADDRESS,E...` |
| `/opt/apps/twenty-rnetwork/.env` | plain | `TAG,PG_DATABASE_PASSWORD,SERVER_URL,APP_SECRET,STORAGE_TYPE,EMAIL_FROM_ADDRESS,E...` |
| `/opt/apps/twenty-votc/.env` | plain | `TAG,PG_DATABASE_PASSWORD,SERVER_URL,APP_SECRET,STORAGE_TYPE,EMAIL_FROM_ADDRESS,E...` |
| `/opt/apps/twenty/.env` | plain | `SERVER_URL,IS_MULTIWORKSPACE_ENABLED,DEFAULT_SUBDOMAIN,PG_DATABASE_USER,PG_DATAB...` |
| `/opt/apps/umami/.env` | plain | `APP_SECRET,DB_PASSWORD` |
| `/opt/apps/unicart/.env` | plain | `DATABASE_URL,DB_PASSWORD,ANTHROPIC_API_KEY,PRIVACY_API_KEY,PORT,NODE_ENV,MCP_SER...` |
| `/opt/apps/upload-service/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/apps/vaultwarden/.env` | plain | `VW_ADMIN_TOKEN,VW_CH_ADMIN_TOKEN,VW_SMTP_PASSWORD,VW_CH_SMTP_PASSWORD` |
| `/opt/apps/voice-command/server/.env` | plain | `ENABLE_DIARIZATION,HF_TOKEN` |
| `/opt/apps/yield-vault/.env` | plain | `SANDBOX_MODE,DB_USER,DB_PASSWORD,DB_NAME,VAULT_API_KEY,POLL_INTERVAL_SECONDS,HAR...` |
| `/opt/apps/youtube-transcriber/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_PROJECT_SLUG,INFISICAL_SEC...` |
| `/opt/clip-forge/.env` | plain | `POSTGRES_USER,POSTGRES_PASSWORD,POSTGRES_DB,DATABASE_URL,REDIS_URL,WHISPER_API_U...` |
| `/opt/erpnext/.env` | plain | `DB_ROOT_PASSWORD,DB_NAME,DB_USER,DB_PASSWORD,FRAPPE_SITE_NAME,ADMIN_PASSWORD` |
| `/opt/immich/.env` | plain | `UPLOAD_LOCATION,DB_DATA_LOCATION,TZ,IMMICH_VERSION,DB_PASSWORD,DB_USERNAME,DB_DA...` |
| `/opt/jeffsi-meet/.env` | plain | `CONFIG,TZ,PUBLIC_URL,JVB_ADVERTISE_IPS,ENABLE_AUTH,ENABLE_GUESTS,AUTH_TYPE,JICOF...` |
| `/opt/media-server/.env` | plain | `DOMAIN,MEDIA_SUBDOMAIN,TZ,PUID,PGID,TRANSMISSION_USER,TRANSMISSION_PASS,VPN_ENAB...` |
| `/opt/meeting-intelligence/.env` | plain | `POSTGRES_PASSWORD,API_SECRET_KEY,XMPP_SERVER,XMPP_DOMAIN,JIBRI_XMPP_PASSWORD,JIB...` |
| `/opt/mycopunk-swag-store/.env` | plain | `DB_PASSWORD,STRIPE_SECRET_KEY,STRIPE_PUBLISHABLE_KEY,STRIPE_WEBHOOK_SECRET,PRODI...` |
| `/opt/n8n/.env` | plain | `POSTGRES_PASSWORD,N8N_ENCRYPTION_KEY,N8N_USER,N8N_PASSWORD,N8N_PUBLIC_API_ENABLE...` |
| `/opt/open-notebook/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_PROJECT_SLUG,INFISICAL_SEC...` |
| `/opt/payment-infra/.env` | plain | `DB_USER,DB_PASSWORD,DB_NAME,DATABASE_URL,REDIS_URL,OPENFORT_API_KEY,OPENFORT_PUB...` |
| `/opt/postiz/bondingcurve/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,POSTGRES_PASSWORD` |
| `/opt/postiz/crypto-commons/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,POSTGRES_PASSWORD,COMPOSE_FILE` |
| `/opt/postiz/main/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,POSTGRES_PASSWORD` |
| `/opt/postiz/p2pfoundation/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,POSTGRES_PASSWORD` |
| `/opt/postiz/shared-temporal/.env` | plain | `TEMPORAL_POSTGRES_PASSWORD` |
| `/opt/receipt-wrangler/.env` | plain | `ENCRYPTION_KEY,SECRET_KEY,DB_USER,DB_PASSWORD,DB_NAME,REDIS_PASSWORD` |
| `/opt/rspace-online-dev/.env` | mixed (Infisical + plain) | `COMPOSE_PROJECT_NAME,INFISICAL_DEV_CLIENT_ID,INFISICAL_DEV_CLIENT_SECRET,JWT_DEV...` |
| `/opt/rspace-online/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_AI_CLIENT_ID,INFISICAL_AI_...` |
| `/opt/rspace-zk-staging/.env` | mixed (Infisical + plain) | `COMPOSE_PROJECT_NAME,ZK_STAGING_DB_PASSWORD,ZK_STAGING_JWT_SECRET,ZK_STAGING_INT...` |
| `/opt/secrets/cloudflare/.env` | plain | `CLOUDFLARE_ACCOUNT_ID,CLOUDFLARE_INFRA_TOKEN,CLOUDFLARE_TUNNEL_TOKEN,CLOUDFLARE_...` |
| `/opt/secrets/crypto-commons/.env` | plain | `STRIPE_SECRET_KEY,STRIPE_WEBHOOK_SECRET,NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY,GOOGL...` |
| `/opt/secrets/fal/.env` | plain | `FAL_KEY` |
| `/opt/secrets/gemini/.env` | empty | `` |
| `/opt/secrets/google/.env` | plain | `GOOGLE_CLIENT_ID,GOOGLE_CLIENT_SECRET,GOOGLE_API_KEY` |
| `/opt/secrets/katheryn-website/.env` | plain | `DIRECTUS_STORE_TOKEN,PAYPAL_CLIENT_ID,PAYPAL_CLIENT_SECRET,PAYPAL_MODE,NEXT_PUBL...` |
| `/opt/secrets/mailcow/.env` | plain | `MAILCOW_SMTP_HOST,MAILCOW_SMTP_PORT,MAILCOW_SMTP_USER_JE,MAILCOW_SMTP_PASS_JE,MA...` |
| `/opt/secrets/pocket-id/.env` | plain | `POCKET_ID_API_KEY,POCKET_ID_URL` |
| `/opt/secrets/r2-backup/.env` | empty | `` |
| `/opt/secrets/resend/.env` | plain | `RESEND_API_KEY` |
| `/opt/secrets/rnotes/.env` | plain | `DB_PASSWORD,NEXT_PUBLIC_RSPACE_URL,RSPACE_INTERNAL_URL,NEXT_PUBLIC_ENCRYPTID_SER...` |
| `/opt/secrets/worldplay/.env` | plain | `ADMIN_TOKEN,SMTP_PASS,GOOGLE_CREDENTIALS` |
| `/opt/services/docling-service/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_PROJECT_SLUG,INFISICAL_SEC...` |
| `/opt/services/image-forge/.env` | plain | `ENGINE_POOL_AUTH_TOKEN` |
| `/opt/services/morpheus-engine-pool/.env` | plain | `ENGINE_POOL_AUTH_TOKEN` |
| `/opt/services/newsletter-api/.env` | plain | `RESEND_API_KEY` |
| `/opt/services/payment-forge/.env` | infisical-only | `INFISICAL_PROJECT_SLUG,INFISICAL_ENV` |
| `/opt/soulsync-player/.env` | plain | `NAVIDROME_ADMIN_USER,NAVIDROME_ADMIN_PASS,ACCESS_CODE,GUEST_PASSWORD` |
| `/opt/twenty-crm/.env` | plain | `POSTGRES_PASSWORD,APP_SECRET` |
| `/opt/websites/cofi/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/websites/cosmolocal-website/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,MYSQL_ROOT_PASSWORD,MYSQL_PASSWORD,N...` |
| `/opt/websites/crypto-commons-gather.ing-website-staging/.env` | plain | `GOOGLE_SHEET_ID,GOOGLE_SHEET_NAME,GOOGLE_SERVICE_ACCOUNT_KEY,SMTP_HOST,SMTP_PORT...` |
| `/opt/websites/crypto-commons-gather.ing-website/.env` | plain | `GOOGLE_SHEET_ID,GOOGLE_SHEET_NAME,GOOGLE_SERVICE_ACCOUNT_KEY,SMTP_HOST,SMTP_PORT...` |
| `/opt/websites/crypto-commons-website-2.0/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/websites/flights-search/.env` | plain | `AMADEUS_CLIENT_ID,AMADEUS_CLIENT_SECRET` |
| `/opt/websites/higgys-android-website/.env` | plain | `ADMIN_PASSWORD` |
| `/opt/websites/jefflix-website/.env` | mixed (Infisical + plain) | `SMTP_HOST,SMTP_PORT,SMTP_USER,SMTP_PASS,ADMIN_EMAIL,INFISICAL_CLIENT_ID,INFISICA...` |
| `/opt/websites/katheryn-website/directus/.env` | plain | `DB_USER,DB_PASSWORD,DB_DATABASE,ADMIN_EMAIL,ADMIN_PASSWORD,DIRECTUS_SECRET` |
| `/opt/websites/mycofi-earth-website/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/websites/mycro-zine/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_PROJECT_SLUG,INFISICAL_SEC...` |
| `/opt/websites/p2pwiki/.env` | plain | `DB_ROOT_PASSWORD,DB_PASSWORD` |
| `/opt/websites/p2pwikifr/.env` | plain | `DB_ROOT_PASSWORD,DB_PASSWORD` |
| `/opt/websites/personal-dashboard/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,INFISICAL_PROJECT_SLUG,INFISICAL_SEC...` |
| `/opt/websites/rNetwork-online/.env` | plain | `TWENTY_DEMO_API_KEY,TWENTY_DEMO_API_URL` |
| `/opt/websites/rPubs-online/.env` | plain | `CF_API_TOKEN` |
| `/opt/websites/rauctions-online/.env` | mixed (Infisical + plain) | `DB_PASSWORD,DATABASE_URL,NEXT_PUBLIC_ENCRYPTID_SERVER_URL,WALLET_SERVICE_URL,NEX...` |
| `/opt/websites/rauctions-online/.next/standalone/.env` | plain | `DATABASE_URL,AUTH_SECRET,WALLET_SERVICE_URL,NEXT_PUBLIC_TRANSAK_API_KEY,NEXT_PUB...` |
| `/opt/websites/rbooks-online/.env` | plain | `ENCRYPTID_DEMO_SPACES` |
| `/opt/websites/rcart-online/.env` | mixed (Infisical + plain) | `DB_PASSWORD,NEXT_PUBLIC_ENCRYPTID_SERVER_URL,DB_PASSWORD_ENCODED,INFISICAL_CLIEN...` |
| `/opt/websites/rfunds-online/.env` | plain | `ENCRYPTID_DEMO_SPACES` |
| `/opt/websites/rmaps-online/.env` | plain | `ENCRYPTID_DEMO_SPACES` |
| `/opt/websites/rmaps-online/sync-server/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/websites/rnotes-online/.env` | mixed (Infisical + plain) | `DB_PASSWORD,NEXT_PUBLIC_RSPACE_URL,RSPACE_INTERNAL_URL,NEXT_PUBLIC_ENCRYPTID_SER...` |
| `/opt/websites/rsocials-online/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,ENCRYPTID_DEMO_SPACES` |
| `/opt/websites/rsocials-online/.next/standalone/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,ENCRYPTID_DEMO_SPACES` |
| `/opt/websites/rsocials-online/infisical/.env` | mixed (Infisical + plain) | `INFISICAL_DB_PASS,INFISICAL_ENCRYPTION_KEY,INFISICAL_AUTH_SECRET,SMTP_PASSWORD` |
| `/opt/websites/rspace-online.bak/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,POSTGRES_PASSWORD,JWT_SECRET,ENCRYPT...` |
| `/opt/websites/rtrips-online/.env` | plain | `DB_PASSWORD,GEMINI_API_KEY,NEXT_PUBLIC_RSPACE_URL,RSPACE_INTERNAL_URL,NEXT_PUBLI...` |
| `/opt/websites/rvote-online/.env` | plain | `DATABASE_URL,DB_PASSWORD,NEXTAUTH_SECRET,NEXTAUTH_URL,SMTP_HOST,SMTP_PORT,SMTP_U...` |
| `/opt/websites/translation-cache/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/websites/valley-commons/.env` | mixed (Infisical + plain) | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET,POSTGRES_PASSWORD,MOLLIE_API_KEY,SMT...` |
| `/opt/websites/worldplay-website/.env` | infisical-only | `INFISICAL_CLIENT_ID,INFISICAL_CLIENT_SECRET` |
| `/opt/websites/xhivart-mirror/.env` | plain | `SMTP_HOST,SMTP_PORT,SMTP_USER,SMTP_PASS,SMTP_FROM,ADMIN_PASSWORD,LISTMONK_URL,LI...` |
| `/opt/websites/xhivart-mirror/listmonk/.env` | plain | `LISTMONK_DB_PASSWORD,LISTMONK_ADMIN_PASSWORD` |
