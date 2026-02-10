---
id: task-18
title: Deploy Mailcow email server and consolidate SMTP services
status: Done
assignee: ['@claude']
created_date: '2026-02-08 12:00'
updated_date: '2026-02-09 21:30'
labels: [email, infrastructure, mailcow]
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
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
### Mailcow Deployment (2026-02-08)
- Deployed at `/opt/mailcow/` on Netcup RS 8000
- Hostname: mx.jeffemmett.com (A record, direct IP, not proxied)
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
1. Gitea - SendGrid → Mailcow (mx.jeffemmett.com:465)
2. Mattermost - Resend → Mailcow
3. Listmonk - Resend → Mailcow (3 SMTP servers configured per domain)
4. Cal.com - Resend → Mailcow
5. Docmost (docs.jeffemmett.com) - New SMTP config added
6. Docmost (docs.cosmolocal.world) - New SMTP config added

### Remaining (not migrated)
- Ghost CosmoLocal: env vars baked into container, needs recreation
- 7 Resend API SDK services: need code changes (jefflix, rvote, cosmolocal, xhivart, valley-commons, worldplay, newsletter-api)
- 13 domains on Cloudflare Email Routing: left as-is (free, working)

### Email Deliverability
- DKIM: PASS (2048-bit RSA, all 3 domains)
- SPF: PASS (hardfail -all)
- DMARC: PASS (p=quarantine)
- PTR: mx.jeffemmett.com (IPv4 only, IPv6 disabled)
- Google Postmaster Tools: verified for all 3 domains
- New IP reputation: building (initial emails may go to spam)

### Listmonk RBAC (v5.1.0)
- Removed legacy admin_username/admin_password from config.toml
- Created API user: listmonk-api (Super Admin, token-based auth)
- Created user role: Editor (limited permissions, no admin access)
- Created list role: CosmoLocal Editor (scoped to CosmoLocal World list only)
- Bryan user: bryan@cosmolocal.world (Editor + CosmoLocal list access)
- Created CosmoLocal World list (id=21) for cosmolocal.world newsletters

### Docmost Multi-Instance Setup
- docs.jeffemmett.com → docmost container (Jeff's Workspace)
- docs.cosmolocal.world → docmost-cl container (CosmoLocal workspace)
- Shared Postgres (two databases: docmost + docmost_cosmolocal)
- Shared Redis (db 0 + db 1)
- 4 containers total instead of 6 (resource-efficient)
- cosmolocal.world uses proxied A record + Traefik websecure with LE
<!-- SECTION:NOTES:END -->
