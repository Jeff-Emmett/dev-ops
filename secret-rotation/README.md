# Secret Rotation

Self-hosted Infisical (free tier) doesn't include built-in rotation. This is a
custom rotation cron that:

1. For each secret due for rotation:
   - Generates a new random value
   - Pushes the new value to the upstream platform (e.g. updates the Gitea
     webhook config, calls `setWebhook` on Telegram, ALTERs the Postgres
     user password, etc.)
   - PATCHes the new value into Infisical (`rspace`/prod project)
   - Triggers a downstream redeploy where needed
2. Appends an audit log entry
3. Emails Jeff a summary

## Layout

```
secret-rotation/
├── README.md
├── registry.json         which secrets, what cadence, which rotator
├── audit/                append-only JSONL audit log (per-day file)
├── rotate.ts             driver — reads registry, decides what's due,
│                          calls each rotator, writes audit log
├── rotators/             per-platform rotator implementations
│   ├── _types.ts
│   ├── _infisical.ts    Infisical write API (rspace/prod)
│   ├── github.ts        GitHub repo webhook
│   ├── gitea.ts         Gitea repo webhook
│   ├── gitlab.ts        GitLab project webhook
│   ├── linear.ts        Linear webhook
│   ├── calcom.ts        Cal.com webhook
│   ├── sentry.ts        Sentry integration
│   ├── telegram.ts      Telegram bot setWebhook (url-secret)
│   ├── posthog.ts       PostHog webhook destination
│   ├── mattermost.ts    Mattermost outgoing webhook
│   ├── discord.ts       Internal Discord relay (no upstream API call)
│   ├── postgres.ts      DB password ALTER USER + Infisical
│   └── internal.ts      Pure-internal secrets (no upstream sync)
└── scripts/
    ├── install-cron.sh
    └── test-rotation.sh   dry-run mode
```

## Cadence

Default: **monthly** for app webhook secrets, **quarterly** for DB passwords,
**weekly** for INBOX_ADMIN_TOKEN. Configurable per-secret in `registry.json`.

## Running

```bash
# Dry-run (compute what would rotate, no writes)
bun run rotate.ts --dry-run

# Rotate one specific secret (skips cadence check)
bun run rotate.ts --secret GITEA_WEBHOOK_SECRET --force

# Rotate everything that's due
bun run rotate.ts
```

## Cron

`scripts/install-cron.sh` installs a daily systemd timer (3am local) that runs
the driver. Each invocation only rotates what's actually due per the cadence
in registry.json.

## What can't be rotated

- **OAuth refresh tokens** (Spotify/Strava/Fitbit/Google Drive/YouTube/MS Graph)
  — require a human to re-authorize via browser
- **Platform-issued tokens** (Stripe signing, Slack signing, Notion, Zotero,
  Readwise, Oura PAT, Figma PAT, Miro PAT, Plaid client secret) — controlled
  by their UI; no rotation API
- **API URLs / config flags** (TWENTY_API_URL, HN_ENABLED, MSGRAPH_FEATURES)
  — not secrets

These are tracked in `registry.json` with `rotator: "manual"` so they appear
in audit reports as "needs human attention" past their expiry threshold.
