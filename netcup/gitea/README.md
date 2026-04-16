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

## History

- 2026-04-16: Initial import into dev-ops. Runner retuned:
  capacity 1 → 2, daemon mem_limit 12g → 512m, cpus 2 → 1, per-job
  swap disabled. Details in the deployment-tracker memory under
  `gitea-runner-retuning-20260416.md`.
