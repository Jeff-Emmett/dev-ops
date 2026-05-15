# Runbook: rotate Stripe credentials (crypto-commons gather.ing)

**Cadence**: 365 days. Inventory entry: `stripe-crypto-commons`.

These keys move real money. The bundle at `/opt/secrets/crypto-commons/.env`
holds:

| Var | Type | Notes |
|---|---|---|
| `STRIPE_SECRET_KEY` | Live API secret (`sk_live_*`) | server-side payment creation |
| `STRIPE_WEBHOOK_SECRET` | Webhook signing secret | verifies inbound webhook authenticity |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | Publishable (`pk_live_*`) | shipped to browser; not secret but rotated alongside for consistency |
| `GOOGLE_SERVICE_ACCOUNT_KEY` | Google Cloud SA JSON | separate concern — different lifecycle |

Stripe SECRET key rotation is **non-trivial**:

- Stripe doesn't let you "expire" a key with a hard cutoff. You create a
  new SECRET, deploy it, and **manually revoke the old** once confident.
- The webhook secret is per-endpoint; rotating it requires re-registering
  the webhook endpoint (or rolling the secret in-place via the dashboard
  if Stripe supports it for your account tier).
- Publishable keys can be rotated, but rotating it forces every active
  client session to refresh — coordinate with frontend deploys.

## Pre-flight

- Stripe dashboard open in **live mode**: <https://dashboard.stripe.com/apikeys>
- Webhook endpoints page: <https://dashboard.stripe.com/webhooks>
- Confirm baseline:
  ```bash
  # Last successful charge in Stripe — note timestamp so you can confirm
  # post-rotation charges still come through.
  # (Visual check in dashboard.)
  ```
- Identify the consumer:
  ```bash
  ssh netcup-full 'grep -rl /opt/secrets/crypto-commons/.env /opt/apps /opt/services 2>/dev/null'
  ```
  Expected: the crypto-commons-gather.ing-website compose stack at
  `/opt/websites/crypto-commons-gather.ing-website/` or similar.

## Steps

### 1. Create the new restricted SECRET key

Stripe dashboard → Developers → API keys → "Create restricted key".

- Name: `crypto-commons-rotated-YYYY-MM-DD`.
- **Permissions**: copy from the existing restricted key (Stripe shows the
  permission set on each key's detail page). For the crypto-commons site,
  typical perms are: Charges:Write, Customers:Write, PaymentIntents:Write,
  Webhook Endpoints:Read.
- Save the new SECRET — shown ONCE. Drop into
  `~/.secrets/private/stripe-crypto-commons.new` (mode 600).

If the existing key is a full SECRET (not restricted), use the same
"Reveal key" → "Roll" flow on its detail page. Stripe rolls in-place
and lets you set a grace period during which both old + new work.

### 2. Update server-side consumer .env

```bash
NEW_SK=$(cat ~/.secrets/private/stripe-crypto-commons.new)
ssh netcup-full "cp /opt/secrets/crypto-commons/.env /opt/secrets/crypto-commons/.env.bak-pre-rotate-\$(date -u +%Y%m%d-%H%M%S)"
ssh netcup-full "sed -i 's|^STRIPE_SECRET_KEY=.*|STRIPE_SECRET_KEY=${NEW_SK}|' /opt/secrets/crypto-commons/.env"
ssh netcup-full "chmod 600 /opt/secrets/crypto-commons/.env"
```

### 3. Restart the consumer

```bash
# Find consumer (one of):
ssh netcup-full 'cd /opt/websites/crypto-commons-gather.ing-website && docker compose up -d'
# or
ssh netcup-full 'cd /opt/apps/crypto-commons-app && docker compose up -d'  # confirm path first
```

### 4. Smoke test — webhook signature

The webhook secret signs Stripe → your-server callbacks. Test:

```bash
# From Stripe dashboard → Webhooks → your endpoint → "Send test event"
# Then check your service logs for "Webhook signature verified" or 200.
ssh netcup 'docker logs --tail 30 -f <consumer-container>'
```

If the test event responds 400 / signature mismatch, the webhook secret
in .env doesn't match the endpoint's. Roll the webhook secret in Step 5.

### 5. (If needed) rotate the webhook secret

Stripe dashboard → Webhooks → select the endpoint → "Roll secret".

1. Copy the new value.
2. Update `STRIPE_WEBHOOK_SECRET` in `/opt/secrets/crypto-commons/.env`.
3. Restart consumer.
4. Send another test event; expect 200.

### 6. (Optional) rotate the publishable key

Only if there's reason (compromise, ID enumeration concern). Publishable
keys are by design exposed to the browser, so rotation is more about
revocation than privacy.

```bash
# Stripe → API keys → "Roll" on the publishable key.
# Update NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY in the stash.
# Rebuild + redeploy the consumer (Next.js needs a rebuild for NEXT_PUBLIC_*).
```

### 7. Revoke the OLD SECRET key

Only after smoke tests pass and you've confirmed at least one live
charge or webhook delivery on the NEW key.

Stripe → API keys → click old key → "Revoke key" (or wait out the
in-place roll grace period if you used that flow).

### 8. Cleanup + record

```bash
shred -u ~/.secrets/private/stripe-crypto-commons.new
cd ~/Github/dev-ops
./security/mark-rotated.sh stripe-crypto-commons
git add security/secrets-inventory.yaml
git commit -m "security: rotate stripe-crypto-commons (mark inventory)"
```

## If something goes wrong

- **Webhook 400s after rotation**: webhook secret mismatch. Step 5.
- **Charges fail with `Invalid API key`**: a consumer still has the old
  SECRET. `ssh netcup-full 'grep -rln STRIPE_SECRET_KEY /opt'` to find
  shadow copies (frontend builds bake the publishable key in; SECRET
  should only ever be server-side).
- **You revoked too early and live charges break**: create a new
  restricted key immediately (Step 1), redeploy, then revoke the
  intermediate-state key.
- **Suspect compromise (key leaked publicly)**: revoke immediately at
  Stripe, accept payment outage, then rotate cleanly. Stripe has
  fraud-monitoring that may flag this for you automatically — check
  the email associated with the account.

## Cross-references

- Inventory: `stripe-crypto-commons`
- Related: `katheryn-website-secrets` (uses PayPal, not Stripe — separate)
- Stripe security guide: <https://stripe.com/docs/keys#safe-keys>
