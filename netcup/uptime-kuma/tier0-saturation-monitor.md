# Tier 0 Saturation Monitor — Uptime Kuma Setup

Catches the failure mode that took down all Netcup-served sites on 2026-05-09:
CrowdSec was capped at 256 MB by `enforce-container-limits.sh`, saturated under
forwardAuth load, response time hit 5+ seconds, bouncer-traefik's 5s timeout
fail-deny'd → every site returned 403.

Probe is `dev-ops/netcup/scripts/uptime-kuma-tier0-probe.sh`. Pushes status DOWN
if any Tier 0 container is at >90% of its `mem_limit`.

## Setup walkthrough

1. **Create the push monitor in Uptime Kuma**
   - Go to https://status.jeffemmett.com → **Add New Monitor**
   - Monitor Type: **Push**
   - Friendly Name: `Tier 0 Saturation`
   - Heartbeat Interval: `300` (5 minutes — matches the timer)
   - Heartbeat Retry Interval: `60`
   - Resend Notification every X times: `1` (page on first failure)
   - Notifications: enable **Mailcow Email Alerts** (id=1) — same as host-health probe
   - Save → copy the push URL token (the long string after `/api/push/`)

2. **Add token to `/etc/uptime-kuma-push.env`** (mode 600)
   ```
   echo 'TIER0_SATURATION_PUSH_TOKEN="<token-from-step-1>"' | sudo tee -a /etc/uptime-kuma-push.env
   sudo chmod 600 /etc/uptime-kuma-push.env
   ```

3. **Deploy probe + systemd unit/timer**
   ```
   sudo scp dev-ops/netcup/scripts/uptime-kuma-tier0-probe.sh netcup-full:/opt/scripts/
   sudo scp dev-ops/netcup/scripts/uptime-kuma-tier0-probe.{service,timer} netcup-full:/etc/systemd/system/
   ssh netcup-full 'chmod +x /opt/scripts/uptime-kuma-tier0-probe.sh && \
     systemctl daemon-reload && \
     systemctl enable --now uptime-kuma-tier0-probe.timer'
   ```

4. **Verify a manual push**
   ```
   ssh netcup-full 'systemctl start uptime-kuma-tier0-probe.service && \
     tail /var/log/uptime-kuma-tier0-probe.log'
   ```
   Expect: `status=up worst=<name>@<pct>%`. The Kuma monitor should flip to UP within 30s.

## What it watches

- Explicit names: `traefik`, `infisical`, `gitea`, `uptime-kuma`, `restic`, `crowdsec`, `bouncer-traefik`
- Pattern: `^mailcowdockerized-(postfix|dovecot|mysql|rspamd|sogo|redis|nginx|php-fpm)-mailcow-1$`

Mirrors the `TIER0_NAMES` array in `enforce-oom-tiers.sh`. **Keep in sync** if you add Tier 0 services.

## Tuning

- Threshold default: 90%. Edit `THRESHOLD_PCT` at the top of the probe script.
- Probes every 5 min. Edit the timer's `OnUnitActiveSec` to change cadence.
- Containers with no `mem_limit` (unbounded) are skipped — they can't saturate against a missing cap.

## Why not also monitor Tier 1?

Could be added later. Tier 1 services are designed to die-and-be-restarted under pressure (kernel OOM-kills sandboxes first, then them). Tier 0 saturation is the one that cascades catastrophically because the security perimeter fails closed.
