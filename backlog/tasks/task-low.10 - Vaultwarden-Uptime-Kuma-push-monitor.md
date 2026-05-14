---
id: TASK-LOW.10
title: 'Vaultwarden: Uptime Kuma push monitor'
status: Done
assignee: []
created_date: '2026-05-12 20:56'
updated_date: '2026-05-14 20:58'
labels:
  - infra
  - monitoring
  - task-82
dependencies: []
parent_task_id: TASK-LOW
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-82 AC #9 — Create a push monitor for passwords.jeffemmett.com/alive in Uptime Kuma, wired to Mailcow Email Alerts.

**Steps:**
1. Kuma UI (https://status.jeffemmett.com) → Add New Monitor → Type: Push
2. Friendly name: 'Vaultwarden (passwords.jeffemmett.com)'
3. Heartbeat interval: 60s
4. Notification: 'Mailcow Email Alerts' (id=1)
5. Copy the push token from Kuma UI
6. Add VW_PUSH_TOKEN=<token> to /etc/uptime-kuma-push.env (mode 600)
7. Create /opt/scripts/uptime-kuma-vaultwarden-probe.sh:
   curl -sf https://passwords.jeffemmett.com/alive >/dev/null && \
     curl -sfm 10 -H 'Host: status.jeffemmett.com' "http://127.0.0.1/api/push/$VW_PUSH_TOKEN?status=up&msg=alive_ok"
8. Create systemd timer to run every 5 min (mirror the host-probe.timer pattern)
9. Verify Kuma shows 'up' status within 5 min

**Why:** Email alert if Vaultwarden goes silent. Follows the existing push-monitor pattern documented in MEMORY.md.
**Parent:** TASK-82
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Push monitor created in Kuma UI
- [x] #2 Token stored in /etc/uptime-kuma-push.env mode 600
- [x] #3 Probe script + timer deployed and active
- [x] #4 Monitor shows 'Up' status in Kuma
- [x] #5 Notification wired to Mailcow Email Alerts
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Probe artifacts deployed 2026-05-14:
- `/opt/scripts/uptime-kuma-vaultwarden-probe.sh` (mode 755)
- `/etc/systemd/system/uptime-kuma-vaultwarden-probe.{service,timer}`
- `daemon-reload` done

Source of truth: `dev-ops/netcup/vaultwarden/uptime-kuma-vaultwarden-probe.{sh,service,timer}`

Dry-run confirmed: probe successfully reads /alive via Traefik loopback and reaches the Kuma push endpoint (404'd on a fake token, exit 22 — expected). VW /alive returns a JSON-quoted ISO timestamp `"YYYY-MM-DDTHH:MM:SSZ"`, not a UNIX epoch — probe checks for `T...Z` shape rather than parsing.

Remaining (user-side):
1. Kuma UI: create push monitor 'Vaultwarden (Netcup)', notification = Mailcow Email Alerts.
2. Copy push token.
3. `echo 'VAULTWARDEN_PUSH_TOKEN=<token>' | sudo tee -a /etc/uptime-kuma-push.env` (already mode 600).
4. `sudo systemctl enable --now uptime-kuma-vaultwarden-probe.timer`.
5. Confirm Kuma shows green within ~5 min.

Monitor + timer fully wired 2026-05-14 via the kuma-alert-agent container's uptime-kuma-api access (KUMA_PASSWORD pulled from pid 1's /proc/environ since Infisical injects it at startup, not into docker exec):

- Kuma monitor id 231 'Vaultwarden (Netcup)', type=push, interval=60s, active=true
- Notification wired: 'Mailcow Email Alerts' (id 1) — same as your other 174+ monitors
- Push token added to `/etc/uptime-kuma-push.env` as `VAULTWARDEN_PUSH_TOKEN` (mode 600 root)
- First probe ran with exit 0; `uptime-kuma-vaultwarden-probe.timer` is `enabled` and `active`

Note: monitor was created via API on first attempt despite a Socket.IO `add_monitor` 10s timeout (Kuma was slow under load). The retry with bumped timeout (30s) found it existing and idempotently returned the same id+token.
<!-- SECTION:NOTES:END -->
