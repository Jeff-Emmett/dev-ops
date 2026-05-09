# Cloudflare Access Inventory

**32 apps, 39 policies**  (snapshot 2026-05-09)

This is the source-of-truth export from CF Access for the Authentik migration (TASK-83 Phase A).

## Apps by Decision Pattern

### Bypass / Public (3)

| App | Domain | Policies |
|---|---|---|
| Newsletter Public Subscribe (Bypass) | `newsletter.jeffemmett.com/subscribe` | Bypass - Public Newsletter Subscribe (bypass) |
| Deploy Webhook | `deploy.jeffemmett.com` | Allow Jeff (allow); Bypass - Webhook (bypass) |
| Immich Photos | `photos.jeffemmett.com` | Allow Jeff (allow); Bypass - Immich App API (bypass) |

### Allow-Listed (29)

| App | Domain | Policies | Identity Sources |
|---|---|---|---|
| Files (jefflix.lol) | `downloads.jefflix.lol` | Allow Jeff & Stevie | email |
| Infisical Secrets | `secrets.jeffemmett.com` | Allow Jeff; infisical-api auth; GitHub Actions Service Token | email, service_token |
| Email Relay | `email-relay.jeffemmett.com` | Allow Jeff | email |
| Label Printer | `label.jeffemmett.com` | Allow Jeff | email |
| OCR Service | `ocr.jeffemmett.com` | Allow Jeff | email |
| Voice Command API | `voice.jeffemmett.com` | Allow Jeff | email |
| Knowledge Graph | `graph.jeffemmett.com` | Allow Jeff | email |
| Blender API | `blender.jeffemmett.com` | Allow Jeff | email |
| Analytics (Umami) | `analytics.jeffemmett.com` | Allow Jeff | email |
| Uptime Kuma Status | `status.jeffemmett.com` | Allow Jeff | email |
| VPN Admin (Headscale) | `vpn-admin.jeffemmett.com` | Allow Jeff | email |
| PentAGI Security Testing | `pentest.jeffemmett.com` | Allow Jeff | email |
| Arr Suite (jefflix.lol) | `prowlarr.jefflix.lol` | Allow Jeff | email |
| CRM | `crm.jeffemmett.com` | Allow Jeff | email |
| Katheryn CMS | `katheryn-cms.jeffemmett.com` | Allow Jeff | email |
| Social & Newsletter | `social.jeffemmett.com` | Allow Jeff | email |
| Notebooks & Docs | `notebook.jeffemmett.com` | Allow Jeff | email |
| Dashboard | `dashboard.jeffemmett.com` | Allow Jeff | email |
| Mail Server | `mail.jeffemmett.com` | Allow Jeff | email |
| ClipForge | `clip.jeffemmett.com` | Allow Jeff | email |
| AI Services | `ai.jeffemmett.com` | Allow Jeff | email |
| n8n Automation | `n8n.jeffemmett.com` | Allow Jeff | email |
| ERPNext Admin | `erp.jeffemmett.com` | Allow Jeff | email |
| Syncthing Admin | `sync.jeffemmett.com` | Allow Jeff | email |
| Personal Knowledge Management Network | `pkmn.jeffemmett.com` | Allow emails: 12/12/2025; Admin access | email |
| Backlog Dashboard Login | `backlog.jeffemmett.com` | Allow Jeff | email |
| Media Server Admin | `prowlarr.jeffemmett.com` | Admin Access | email |
| SSH | `ssh.jeffemmett.com` | Allow emails: 12/12/2025; Admin access | email |
| Warp Login App | `mycopunks.cloudflareaccess.com/warp` | Allow emails: 12/12/2025; Allow emails: 12/12/2025 | email |

## Authentik Migration Mapping

Each app above needs an Authentik **Application + Provider (Proxy)** with matching policies translated to **Group / Expression** bindings.

Key translations:
- CF `email`/`emails_only` → Authentik User attribute or Group
- CF `email_domain` → Authentik Group filter or Expression policy on `request.user.email`
- CF `service_token` → Authentik Outpost service-account
- CF `bypass` decision → Authentik unauthenticated forward-auth path or simply no policy
- CF `groups` (Google/GitHub IDP) → Authentik Group sourced from same OAuth provider

See `apps-raw.json` and `access-policies-raw.txt` for the unprocessed source data.