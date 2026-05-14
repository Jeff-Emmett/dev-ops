---
id: TASK-87
title: Rotate CrowdSec LAPI bouncer key (exposed in claude session 2026-05-14)
status: Done
assignee: []
created_date: '2026-05-14 23:17'
updated_date: '2026-05-14 23:50'
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
- [x] #1 New LAPI bouncer registered in CrowdSec; old bouncer entry deleted
- [x] #2 /root/traefik/config/crowdsec.yml updated with new key; old value gone
- [x] #3 Traefik logs confirm successful auth to LAPI after the change (no 'unable to authenticate' errors)
- [x] #4 Bouncer still actively enforcing — verified by hitting Traefik with a known-banned source or by `cscli decisions list` showing live decisions reaching the bouncer
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Rotated 2026-05-14 23:46 UTC.

- New bouncer: `traefik-bouncer-20260514-2346` (registered via `cscli bouncers add`)
- Old bouncers removed: `traefik-bouncer`, stale `traefik-bouncer@10.0.43.4`, and a transient `traefik-bouncer-20260514-2345` from a first attempt that hit a quoting bug
- New LAPI key written to `/root/traefik/config/crowdsec.yml` (backup at `.bak-pre-rotate-20260514-234603`)
- Traefik restarted at 23:49; bouncer's `Last API pull` populated by 23:49:18Z
- Inventory entry `crowdsec-traefik-lapi-key` (added by TASK-88 scope) marked `last_rotated: 2026-05-14`

Automation: `dev-ops/security/rotate-crowdsec-traefik-lapi-key.sh` (idempotent, `--dry-run` support, calls `inventory_mark_rotated`). Future rotations: just run the script.

Two gotchas surfaced and now in memory:
- Python heredoc through SSH → mangled by remote zsh; use scp-edit-scp instead
- Traefik plugin middleware: file-watch reload isn't enough; need `docker restart traefik` for the plugin to rebind config. Script now does this automatically and verifies the post-restart Last API pull.
<!-- SECTION:NOTES:END -->
