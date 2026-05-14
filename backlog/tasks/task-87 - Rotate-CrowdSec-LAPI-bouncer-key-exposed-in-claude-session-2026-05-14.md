---
id: TASK-87
title: Rotate CrowdSec LAPI bouncer key (exposed in claude session 2026-05-14)
status: To Do
assignee: []
created_date: '2026-05-14 23:17'
labels:
  - security
  - crowdsec
  - rotation
  - infra
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
During the Traefik repo re-sync on 2026-05-14, `/root/traefik/config/crowdsec.yml` was read through SSH and its plaintext `crowdsecLapiKey` (value `JmKi...4Z0PU`) entered the Claude conversation context. No external leak — the file stayed on the server (now gitignored at `netcup/traefik/.gitignore` and replaced by `crowdsec.yml.example`). But the value is now in conversation logs and worth rotating for defense-in-depth.

**Rotate via:**
1. On Netcup, in the CrowdSec container, register a new bouncer + delete the old:
   ```
   docker exec crowdsec cscli bouncers add traefik-bouncer-new -o raw
   # capture the printed key
   docker exec crowdsec cscli bouncers delete traefik-bouncer  # or whatever the old name is
   docker exec crowdsec cscli bouncers list
   ```
2. Edit `/root/traefik/config/crowdsec.yml` → set `crowdsecLapiKey:` to the new value.
3. Traefik file-provider watches the config dir and reloads automatically (no restart needed).
4. Verify in Traefik logs: `docker logs traefik 2>&1 | grep -i crowdsec | tail -5` — should show successful auth to LAPI.
5. Test that the bouncer is enforcing decisions: `curl -H 'Host: <any-traefik-host>' http://127.0.0.1` from an IP that's in a CrowdSec decision should still 403.

**Why medium not high:** the file was always root-only on the server; this is precautionary rotation, not a known compromise.

References:
- dev-ops/security/ rotation tooling pattern
- netcup/traefik/config/crowdsec.yml.example (committed reference)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 New LAPI bouncer registered in CrowdSec; old bouncer entry deleted
- [ ] #2 /root/traefik/config/crowdsec.yml updated with new key; old value gone
- [ ] #3 Traefik logs confirm successful auth to LAPI after the change (no 'unable to authenticate' errors)
- [ ] #4 Bouncer still actively enforcing — verified by hitting Traefik with a known-banned source or by `cscli decisions list` showing live decisions reaching the bouncer
<!-- AC:END -->
