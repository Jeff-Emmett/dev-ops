---
id: TASK-51
title: Security scan remediation - remaining items from PentAGI audit
status: To Do
assignee: []
created_date: '2026-02-25 09:30'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Remaining items from the 2026-02-25 PentAGI security audit that were not immediately fixed:

1. Mailcow cert mismatch (port 8443): Certificate issued for mx.jeffemmett.com but hostname resolves as mail.rmail.online. Browser cert validation errors. Low impact since Mailcow UI accessed via Traefik/Cloudflare (not direct IP).

2. OpenSSH 9.3 on port 223: Check if update available. Non-standard port is good. Verify key-only auth enforced.

3. Grid Trading Bot (port 3000): Unauthenticated Next.js app. If this should not be public, add Cloudflare Access or remove. Currently blocked by DOCKER-USER externally.

4. Clean up stalled PentAGI terminal containers: 6 idle kali-linux containers still running from failed scan flows. Run: docker stop pentagi-terminal-{1..6}

5. Unidentified services on ports 1936, 3478, 50300: Identify and document what runs on these ports. 3478 is likely STUN/TURN for WebRTC.

6. Self-signed Mailcow cert (RSA 4096, valid 10 years): Consider replacing with Lets Encrypt cert for Mailcow TLS.
<!-- SECTION:DESCRIPTION:END -->
