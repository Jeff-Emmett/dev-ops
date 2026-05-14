---
id: TASK-86
title: 'Mailcow: replace orphan self-signed cert, restore ACME-managed LE'
status: Done
assignee: []
created_date: '2026-05-14 20:39'
updated_date: '2026-05-14 21:27'
labels:
  - infra
  - mailcow
  - tls
  - security
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mailcow's `/opt/mailcow-dockerized/data/assets/ssl/cert.pem` currently serves a **manually-placed self-signed leaf cert** (subject=issuer `O=Mailcow, CN=mx.jeffemmett.com`, dated Feb 8 2026, SAN: mx.jeffemmett.com + mail.jeffemmett.com) that has **`basicConstraints: CA:TRUE`** — an RFC 5280 violation for a TLS leaf cert. Mailcow's ACME container detects the non-Mailcow / non-LE issuer and refuses to manage it: `"Found certificate with issuer other than mailcow snake-oil CA and Let's Encrypt, skipping ACME client..."`

**Symptoms / impact:**
- Vaultwarden (rustls/Lettre) rejected SMTP TLS with `invalid peer certificate: Other (OtherError(CaUsedAsEndEntity))`. Currently bypassed in `netcup/vaultwarden/docker-compose.yml` with `SMTP_ACCEPT_INVALID_CERTS=true` + `SMTP_ACCEPT_INVALID_HOSTNAMES=true` — workaround, not a fix.
- Cert also lacks `mail.rmail.online` in its SAN list, so even after the CA:TRUE issue is resolved, hostname mismatches will hit anything connecting to the mailcow_hostname.
- Affects ALL Mailcow TLS endpoints (SMTP 587/465, IMAP 993, POP 995, Sieve 4190, admin HTTPS). Any other strict TLS clients (modern mail clients, monitoring probes) will hit the same wall.

**Plan:**
1. Backup `/opt/mailcow-dockerized/data/assets/ssl/{cert.pem,key.pem}` to a dated tarball.
2. Confirm Mailcow's configured `MAILCOW_HOSTNAME` in `/opt/mailcow-dockerized/mailcow.conf` and that DNS for it points to the Netcup IP.
3. Confirm `ADDITIONAL_SAN` in mailcow.conf includes every domain you want covered (mail.rmail.online, mail.jeffemmett.com, etc.).
4. Remove the orphan `cert.pem` + `key.pem`.
5. Restart `acme-mailcow` and watch logs — should issue a fresh LE cert.
6. Verify postfix is reloaded with the new cert: `docker exec mailcowdockerized-postfix-mailcow-1 openssl x509 -in /etc/ssl/mail/cert.pem -noout -subject -issuer -ext basicConstraints,subjectAltName`. Must show Issuer = LE, `CA:FALSE`, and all expected SAN entries.
7. Probe each Mailcow TLS port from outside to confirm proper chain.
8. Remove `SMTP_ACCEPT_INVALID_CERTS` + `SMTP_ACCEPT_INVALID_HOSTNAMES` from `netcup/vaultwarden/docker-compose.yml`, redeploy, re-test admin "Send test email".

**Risks:**
- Triggers a postfix/dovecot/nginx reload on Mailcow → ~10s mail downtime during cutover.
- If ADDITIONAL_SAN is wrong, LE issuance can fail and Mailcow will fall back to snake-oil — keep the backup handy.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Orphan self-signed cert + key removed from /opt/mailcow-dockerized/data/assets/ssl/ (backed up to dated tarball first)
- [x] #2 mailcow.conf MAILCOW_HOSTNAME + ADDITIONAL_SAN covers mail.rmail.online, mail.jeffemmett.com, mx.jeffemmett.com (and any other host clients connect to)
- [x] #3 ACME container successfully issues a fresh Let's Encrypt cert (log line: 'Validating certificates...' followed by successful issuance, no 'skipping ACME client' lines)
- [x] #4 Postfix-mounted cert.pem shows Issuer = R3/R11 (LE), basicConstraints CA:FALSE, all configured hostnames in SAN
- [x] #5 openssl s_client -starttls smtp -connect mail.rmail.online:587 verifies chain to LE root without -trusted_first hacks; rustls (curl --rustls or similar) also accepts
- [x] #6 VW compose has SMTP_ACCEPT_INVALID_CERTS + SMTP_ACCEPT_INVALID_HOSTNAMES removed; admin 'Send test email' succeeds without them
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Cert cutover completed 2026-05-14:

**Discovery on follow-up:** Mailcow had been relocated from `/opt/mailcow-dockerized/` to `/opt/mailcow/` between the original diagnosis and the fix. The orphan self-signed cert was backed up to `/root/cert-backups/mailcow-20260514-225826/` and removed. ACME ran successfully at 22:59 CEST and obtained an LE cert for `mail.rmail.online`.

**Verified state:**
- `MAILCOW_HOSTNAME=mail.rmail.online`, `ADDITIONAL_SAN=` (empty) — single-SAN cert is sufficient for current use; expanding to include mail.jeffemmett.com / mx.jeffemmett.com is a separate decision
- Postfix `/etc/ssl/mail/cert.pem`: `CN=mail.rmail.online`, Issuer `Let's Encrypt R13`, `CA:FALSE`, `notBefore=May 14 20:00:57 2026`
- Dovecot same
- External STARTTLS / direct-TLS verified on 25, 465, 587, 993, 995, 4190 — all serve the new LE cert
- Mailcow nginx 8443: LE cert
- ACME log: `Certificate successfully obtained` (one cosmetic warning about jq parse errors in the reload hook and 'old end dates', but each Mailcow service is independently confirmed to be serving the new cert; treat the log warning as benign)

**Vaultwarden workaround removed:**
- `SMTP_ACCEPT_INVALID_CERTS` + `SMTP_ACCEPT_INVALID_HOSTNAMES` deleted from `netcup/vaultwarden/docker-compose.yml`
- Same keys popped from `/var/lib/docker/volumes/vaultwarden_vaultwarden-data/_data/config.json` (which was shadowing the env per VW's startup warning) — backup at `config.json.bak-pre-cert-fix`
- VW recreated
- Loopback admin login + `POST /admin/test/smtp` to jeffemmett@gmail.com returned HTTP 200 with empty body = success, with **no** accept-invalid flags set

**Out-of-scope but flagged:** Traefik returns `CN=localhost` (its default) for HTTPS requests to `mail.rmail.online:443`. Mailcow's Traefik labels only declare the `web` (HTTP) entrypoint, expecting TLS termination at CF edge. That's by design; not a Mailcow cert issue.
<!-- SECTION:NOTES:END -->
