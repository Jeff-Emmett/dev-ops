---
id: task-18
title: Deploy Mailcow email server and consolidate SMTP services
status: Done
assignee: ['@claude']
created_date: '2026-02-08 12:00'
updated_date: '2026-02-09 23:00'
labels: [email, infrastructure, mailcow, consolidation]
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deploy self-hosted Mailcow email server on Netcup RS 8000 and consolidate all SMTP services (Resend, SendGrid) through Mailcow for simplified email infrastructure across all domains.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Deploy Mailcow on Netcup RS 8000 with Traefik integration
- [x] #2 Configure DNS (MX, SPF, DKIM, DMARC) for jeffemmett.com
- [x] #3 Configure DNS (SPF, DKIM, DMARC) for cosmolocal.world
- [x] #4 Configure DNS (SPF, DKIM, DMARC) for crypto-commons.org
- [x] #5 Migrate Gitea from SendGrid to Mailcow SMTP
- [x] #6 Migrate Mattermost from Resend to Mailcow SMTP
- [x] #7 Migrate Listmonk from Resend to Mailcow SMTP
- [x] #8 Migrate Cal.com from Resend to Mailcow SMTP
- [x] #9 Set up email forwarding jeff@jeffemmett.com → Gmail
- [x] #10 Fix IPv6 PTR issue for outbound SMTP (force IPv4)
- [x] #11 Set up Google Postmaster Tools for all 3 domains
- [x] #12 Slim down Mailcow containers (skip ClamAV, SOGo, Olefy)
- [x] #13 Configure Docmost SMTP for docs.jeffemmett.com
- [x] #14 Configure Docmost SMTP for docs.cosmolocal.world
- [x] #15 Consolidate Twenty CRM 2→1 (multi-workspace on rnetwork.online)
- [x] #16 Consolidate Listmonk 4→1 (single instance, redirect vanity domains)
- [x] #17 Consolidate Docmost 2→1 (single instance, redirect docs.cosmolocal.world)
- [x] #18 Add 10 project domains to Mailcow with noreply@ + newsletter@ aliases
- [x] #19 Configure 13 SMTP entries in Listmonk (one per domain)
- [x] #20 Set MX, SPF, DKIM, DMARC DNS records for all 13 domains
- [x] #21 Set catch-all forwarding (→ Gmail) for all 12 project domains
- [x] #22 Verify all 13 domains on Google Postmaster Tools
- [x] #23 Clean up duplicate Listmonk lists (8 empty duplicates removed)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
### Mailcow Deployment (2026-02-08)
- Deployed at `/opt/mailcow/` on Netcup RS 8000
- Hostname: mail.rmail.online (A record, direct IP, not proxied)
- Web UI: mail.jeffemmett.com (via Cloudflare Tunnel + Traefik)
- Slimmed from 18 to ~12 containers (SKIP_CLAMD, SKIP_OLEFY, SKIP_SOGO)
- RAM reduced from ~2.4GB to ~830MB
- IPv4 forced for outbound SMTP (SNAT_TO_SOURCE=159.195.32.209)
- Self-signed certs (Traefik/Cloudflare handle public SSL)

### SMTP Accounts
- noreply@jeffemmett.com (service account for jeffemmett.com services)
- noreply@cosmolocal.world (service account for cosmolocal services)
- noreply@crypto-commons.org (service account for crypto-commons)
- Credentials saved to /root/.mailcow_smtp_credentials on Netcup

### Sender Aliases (sender_allowed=1)
- newsletter@jeffemmett.com → noreply@jeffemmett.com
- newsletter@cosmolocal.world → noreply@cosmolocal.world
- newsletter@crypto-commons.org → noreply@crypto-commons.org
- gitea@jeffemmett.com → noreply@jeffemmett.com
- schedule@jeffemmett.com → noreply@jeffemmett.com

### Services Migrated to Mailcow SMTP
1. Gitea - SendGrid → Mailcow (mail.rmail.online:465)
2. Mattermost - Resend → Mailcow
3. Listmonk - Resend → Mailcow (3 SMTP servers configured per domain)
4. Cal.com - Resend → Mailcow
5. Docmost (docs.jeffemmett.com) - New SMTP config added
6. Docmost (docs.cosmolocal.world) - New SMTP config added

### Remaining (not migrated)
- Ghost CosmoLocal: env vars baked into container, needs recreation
- 7 Resend API SDK services: need code changes (jefflix, rvote, cosmolocal, xhivart, valley-commons, worldplay, newsletter-api)

### Email Deliverability
- DKIM: PASS (2048-bit RSA, all 13 domains)
- SPF: PASS (~all, all 13 domains)
- DMARC: PASS (p=quarantine, all 13 domains)
- PTR: mail.rmail.online (IPv4 only, IPv6 disabled)
- Google Postmaster Tools: verified for all 13 domains
- New IP reputation: building (initial emails may go to spam)

### Listmonk RBAC (v5.1.0)
- Removed legacy admin_username/admin_password from config.toml
- Created API user: listmonk-api (Super Admin, token-based auth)
- Created user role: Editor (limited permissions, no admin access)
- Created list role: CosmoLocal Editor (scoped to CosmoLocal World list only)
- Bryan user: bryan@cosmolocal.world (Editor + CosmoLocal list access)
- Created CosmoLocal World list (id=21) for cosmolocal.world newsletters

### Consolidation (2026-02-09)

#### Twenty CRM: 2 instances → 1 multi-workspace
- Single instance at /opt/apps/twenty/ with IS_MULTIWORKSPACE_ENABLED=true
- SERVER_URL=https://rnetwork.online (dedicated domain)
- app.rnetwork.online → workspace selector
- fcdm.rnetwork.online → FCDM workspace
- cosmolocal.rnetwork.online → Cosmolocal workspace
- crm.jeffemmett.com → 308 redirect → fcdm.rnetwork.online
- crm.cosmolocal.world → 308 redirect → cosmolocal.rnetwork.online (websecure + LE)
- Old cosmolocal instance torn down (4 containers + volumes freed)

#### Listmonk: 4 instances → 1
- Single instance at /opt/apps/listmonk/
- newsletter.jeffemmett.com → direct route (main)
- newsletter.cosmolocal.world → direct route (web + websecure/LE, URL preserved)
- newsletter.crypto-commons.org → 308 redirect → newsletter.jeffemmett.com
- votc-newsletter.jeffemmett.com → 308 redirect → newsletter.jeffemmett.com
- 3 empty instances torn down (6 containers + volumes freed)
- 8 duplicate lists removed, 14 lists remain
- 13 SMTP entries configured (one per domain via Mailcow)

#### Docmost: 2 instances → 1
- Single instance at /opt/apps/docmost/
- docmost.jeffemmett.com → direct route (main)
- docs.cosmolocal.world → 308 redirect → docmost.jeffemmett.com (web + websecure/LE)
- Old cosmolocal instance torn down (3 containers + volumes freed)

#### Total: 13 containers freed (~2-3GB RAM saved)

### Newsletter Domain Configuration (2026-02-09)
All 13 domains configured for newsletter sending via Mailcow:

| List | Domain | From Address |
|------|--------|-------------|
| Default/Opt-in | jeffemmett.com | newsletter@jeffemmett.com |
| CosmoLocal World | cosmolocal.world | newsletter@cosmolocal.world |
| Crypto Commons | crypto-commons.org | newsletter@crypto-commons.org |
| MycoFi | mycofi.earth | newsletter@mycofi.earth |
| Mycopunk | mycopunk.xyz | newsletter@mycopunk.xyz |
| Psilo Cybernetics | psilo-cyber.net | newsletter@psilo-cyber.net |
| rSpace | rspace.online | newsletter@rspace.online |
| Trippin | trippinballs.lol | newsletter@trippinballs.lol |
| WORLDPLAY | worldplay.art | newsletter@worldplay.art |
| Compost Capitalism | compostcapitalism.xyz | newsletter@compostcapitalism.xyz |
| Post-Appitalism | post-appitalism.app | newsletter@post-appitalism.app |
| Undernet | undernet.earth | newsletter@undernet.earth |
| Alltornet | alltor.net | newsletter@alltor.net |

Each domain has: noreply@ mailbox, newsletter@ alias, catch-all → Gmail, MX/SPF/DKIM/DMARC DNS, Google Postmaster verified.

### Docmost (post-consolidation)
- Single instance: docmost.jeffemmett.com
- docs.cosmolocal.world redirects to docmost.jeffemmett.com
<!-- SECTION:NOTES:END -->
