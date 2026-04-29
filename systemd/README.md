# systemd units for dev-ops scheduled tasks

Drop-in unit files for the netcup host. Pair with the wrapper scripts in
`scripts/cron/`.

## Layout

| Timer                          | When                  | Service                              | Sends email? |
|--------------------------------|-----------------------|--------------------------------------|--------------|
| `onboarding-rebuild.timer`     | 1st of month, 09:15 UTC | rebuilds `docs/onboarding.pdf`     | no           |
| `smoke-report-email.timer`     | Sunday 18:00 UTC      | weekly smoke-test PDF report         | yes          |
| `secrets-audit-email.timer`    | 1st of month, 09:30 UTC | monthly secrets-rotation PDF audit | yes          |

The existing `security/rotation-digest.timer` (weekly Mon 09:00 UTC text
digest) is unchanged — it's the operational nudge; the new monthly PDF
audit is the audit-trail companion.

## Install on netcup

```bash
sudo cp /opt/dev-ops/systemd/*.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now \
  onboarding-rebuild.timer \
  smoke-report-email.timer \
  secrets-audit-email.timer
```

## Smoke-test a unit by hand

```bash
sudo systemctl start smoke-report-email.service
journalctl -u smoke-report-email.service -n 50
```

## Required tools on host

- `docker` (the Python scripts shell out to `docker exec` on the mailcow
  postfix container for outbound mail; doc-forge runs in another container
  and is reached via HTTPS)
- `python3` with `httpx` and `pyyaml` available system-wide. Install once:
  ```bash
  pip install --break-system-packages httpx pyyaml
  ```
