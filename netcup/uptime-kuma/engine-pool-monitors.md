# Uptime Kuma push monitors — morpheus-engine-pool

Four push monitors track per-engine latency from
morpheus-engine-pool's `/stats` endpoint. The probe runs every 5 min
on Netcup; each engine pushes its `median_ms` as the heartbeat ping
value (so the response-time chart graphs latency over time) and
`n=<count>+median=<X>ms+p95=<Y>ms` as the message.

Engines:

- ffmpeg
- whisper
- imagemagick
- libvips

## One-time setup

### 1. Create four push monitors in Uptime Kuma

Go to https://status.jeffemmett.com → **+ Add New Monitor** and create
each of the four monitors below. Tags + notification settings at the
bottom apply to every entry; only the friendly name and the resulting
**push token** differ.

| Field | Value |
|---|---|
| Monitor Type | **Push** |
| Friendly Name | one of:<br>`Engine pool — ffmpeg latency`<br>`Engine pool — whisper latency`<br>`Engine pool — imagemagick latency`<br>`Engine pool — libvips latency` |
| Heartbeat Interval | `300` (seconds; matches the timer) |
| Retries | `2` |
| Heartbeat Retry Interval | `60` |
| Tags | `engine-pool`, `morpheus`, `forge` |
| Notifications | ☑ Mailcow Email Alerts (id=1) |

After saving each monitor, copy its **Push URL** from the monitor's
details page. The token is the trailing path segment, e.g.
`http://kuma/api/push/abc123…` → token `abc123…`.

### 2. Drop the four tokens into `/etc/uptime-kuma-push.env`

On Netcup as root, append:

```bash
ENGINE_POOL_FFMPEG_PUSH_TOKEN=<token-from-step-1>
ENGINE_POOL_WHISPER_PUSH_TOKEN=<…>
ENGINE_POOL_IMAGEMAGICK_PUSH_TOKEN=<…>
ENGINE_POOL_LIBVIPS_PUSH_TOKEN=<…>
```

Mode 600 root-only. The probe loads this file at start.

### 3. Install probe + timer

From this directory in the dev-ops repo:

```bash
ssh netcup-full "sudo install -m 0755 \
  /opt/apps/dev-ops-repo/netcup/uptime-kuma/engine-pool-stats-probe.sh \
  /opt/scripts/uptime-kuma-engine-pool-probe.sh"

ssh netcup-full "sudo install -m 0644 \
  /opt/apps/dev-ops-repo/netcup/uptime-kuma/uptime-kuma-engine-pool-probe.service \
  /etc/systemd/system/uptime-kuma-engine-pool-probe.service"

ssh netcup-full "sudo install -m 0644 \
  /opt/apps/dev-ops-repo/netcup/uptime-kuma/uptime-kuma-engine-pool-probe.timer \
  /etc/systemd/system/uptime-kuma-engine-pool-probe.timer"

ssh netcup-full "sudo systemctl daemon-reload \
  && sudo systemctl enable --now uptime-kuma-engine-pool-probe.timer"
```

### 4. Verify

```bash
# Trigger one-shot run
ssh netcup-full "sudo systemctl start uptime-kuma-engine-pool-probe.service"

# Confirm timer scheduled
ssh netcup-full "systemctl list-timers uptime-kuma-engine-pool-probe.timer"

# Check next push lands within ~30s on the four monitors
```

Each monitor should turn green within one heartbeat (≤5min). The
response-time chart shows median latency ms over time — useful for
spotting regressions after worker changes or upstream throttling.

## Why push, not HTTP

Engine pool's `/stats` is JSON with nested per-engine data; one HTTP
monitor would only see "200 OK" and miss the per-engine numbers. Four
push monitors give per-engine charts plus selective alerting. Adding
a fifth aggregate monitor (status of `engine-pool-server` itself)
would be overkill — Traefik's `traefik.http.services.engine-pool.
loadbalancer.healthcheck` already exercises `/health` continuously.

## Calibration loop

The same `/stats` endpoint feeds
`dev-ops/scripts/calibrate-engine-costs.py` for ForgeCost weight
tuning in rspace-online's plan optimizer. Re-running calibration
monthly (or when the Kuma chart shows sustained drift) keeps the
optimizer's cost estimates honest.
