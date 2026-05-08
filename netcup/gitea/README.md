# Gitea + act_runner

Self-hosted Gitea at https://gitea.jeffemmett.com, paired with a single
`act_runner` daemon that executes Actions workflows as sibling Docker
containers on the same host.

## Deploy path on netcup

```
/root/gitea/
├── docker-compose.yml       # tracked here
├── runner-config.yaml       # tracked here
├── .env                     # NOT tracked — see .env.example
├── gitea/                   # server data volume
├── postgres/                # DB data volume
└── runner-data/             # runner state (incl. .runner credentials)
```

The versioned files in this directory mirror what lives on the server.
When updating, push here and then `scp` the changes to `/root/gitea/`,
followed by `docker compose up -d <service>`.

## Runner resource shape

The act_runner daemon launches job containers as **siblings** via the
mounted `/var/run/docker.sock`, not as children. This means the runner's
own `mem_limit` and `cpus` only constrain the daemon itself (~5 MiB idle,
negligible CPU). Job limits are set independently in `runner-config.yaml`
under `container.options`.

| Axis | Runner daemon | Per job | Max concurrent |
|---|---|---|---|
| CPU | 1 core | 2 cores | 2 jobs |
| RAM | 512 MiB | 4 GiB | 2 jobs (= 8 GiB peak burst) |
| Swap (per job) | n/a | **disabled** (`--memory-swap=4g`) | |
| pids | default | 512 | |

Swap is disabled per job to prevent a runaway build from compounding
host-level swap pressure.

## Scaling knobs

If build queue backs up, tune in this order:

1. Raise `runner.capacity` in `runner-config.yaml` (2 → 3, max ~4).
   Each step adds ~4 GiB peak burst footprint.
2. Add a second `runner` service (copy the service block, unique
   `GITEA_RUNNER_NAME`, fresh registration token) for horizontal scale.

## Bootstrapping a fresh runner

1. Visit https://gitea.jeffemmett.com/-/admin/actions/runners and
   generate a registration token.
2. Set `GITEA_RUNNER_REGISTRATION_TOKEN` in `.env` on the server.
3. `docker compose up -d runner`. On first boot the runner registers
   itself, writes `./runner-data/.runner`, and ignores the env var from
   then on.

## Stale-Running watchdog (TASK-HIGH.8 + TASK-MEDIUM.11 mitigation)

`act_runner` v0.3.1 has a known reconciliation bug where it reports task completion to the Gitea server but the status update never lands in the `action_run` / `action_run_job` / `action_task` tables. Rows stay at `status=2` (Running) forever even though the runner already stopped the container and wrote the log. The queue jams over time — we hit ~1,800 stale entries before the first manual cleanup on 2026-05-08, and a second jam (408 entries) appeared within an hour of that.

The pattern is recognisable: `status=2 AND stopped > 0` — the runner DID set the `stopped` timestamp when it ended the container, but the status reconciliation never fired. New runs get Skipped because Gitea thinks the runner is busy.

`watchdog-stale-runs.sh` finds those orphaned-terminal rows and marks them `Failure` (status=4). It also cancels `Waiting` (status=1) runs older than 60 min — these are queued behind orphaned ones and would never get picked up.

### Install

```bash
scp netcup/gitea/watchdog-stale-runs.sh netcup-full:/opt/scripts/watchdog-stale-runs.sh
ssh netcup-full "chmod +x /opt/scripts/watchdog-stale-runs.sh"

scp netcup/gitea/watchdog-stale-runs.{service,timer} \
    netcup-full:/etc/systemd/system/

ssh netcup-full "systemctl daemon-reload && \
                 systemctl enable --now watchdog-stale-runs.timer"
```

The timer fires every 15 min. After it stabilises, expect `running` to be ≤4 (one per simultaneously-running workflow) and `waiting` to be ≤1.

### Verify

```bash
ssh netcup-full "/opt/scripts/watchdog-stale-runs.sh"
ssh netcup-full "systemctl status watchdog-stale-runs.timer"
ssh netcup-full "journalctl -u watchdog-stale-runs.service --since '1h ago'"
ssh netcup-full "docker exec gitea-db psql -U gitea -d gitea -tAc \
  \"SELECT count(*) FILTER (WHERE status=2) AS running, \
           count(*) FILTER (WHERE status=1) AS waiting FROM action_run;\""
```

### Tuning

| Variable | Default | Meaning |
|---|---|---|
| `STOPPED_THRESHOLD_MIN` | 5 | Minutes since `stopped` timestamp before declaring orphaned-terminal. |
| `STARTED_THRESHOLD_MIN` | 60 | Minutes since `started` (with no stop signal) before declaring truly stuck. Must be > the longest legitimate workflow duration. |

### Why not upgrade `act_runner`?

That's the eventual fix — Gitea v1.23+ ships a server-side reconciliation watchdog that obsoletes this script. Until that upgrade lands, this is a 1-cron mitigation that doesn't touch any other moving part. The script never modifies legitimately-running rows (`status=2 AND stopped=0` only triggers after `STARTED_THRESHOLD_MIN`, well above the 3h job timeout).

## History

- 2026-04-16: Initial import into dev-ops. Runner retuned:
  capacity 1 → 2, daemon mem_limit 12g → 512m, cpus 2 → 1, per-job
  swap disabled. Details in the deployment-tracker memory under
  `gitea-runner-retuning-20260416.md`.
- 2026-05-08: Stale-Running watchdog added after a queue jam of ~1,800
  entries was traced to act_runner v0.3.1 reconciliation. See
  TASK-HIGH.8 + TASK-MEDIUM.11.
