# payment-forge deploy notes

Canonical repo: `gitea.jeffemmett.com/jeffemmett/payment-forge` (private).
Public service: `https://pay.jeffemmett.com`.

## Deploy path on Netcup

`/opt/services/payment-forge/` (matches doc-forge / image-forge sibling layout).

```bash
ssh netcup-full
cd /opt/services
git clone ssh://git@gitea.jeffemmett.com:223/jeffemmett/payment-forge.git
cd payment-forge
docker compose up -d
```

`.env` shape:

```bash
# Only Infisical credentials live here. All other secrets (Cowswap API key,
# RPC URLs, X402_DEFAULT_PAYTO wallet) come from Infisical at startup.
INFISICAL_PROJECT_SLUG=payment-forge
INFISICAL_ENV=prod
# INFISICAL_CLIENT_ID=<fill in once project provisioned>
# INFISICAL_CLIENT_SECRET=<fill in once project provisioned>
# X402_DEFAULT_PAYTO=<wallet address; activates /demo-paywalled when set>
```

The entrypoint wrapper at `/opt/infisical/entrypoint-wrapper.sh` (volume-mounted)
gracefully no-ops when CLIENT_ID/SECRET aren't set — the forge boots with mock
+ crdt-iou rails fully functional, x402 + cowswap registered but unable to
talk to upstreams until secrets are provisioned.

## Cloudflare tunnel ingress

The Netcup tunnel `netcup-local` (id `a838e9dc-0af5-4212-8af2-6864eb15e1b5`)
uses **remote** ingress config, managed via the Cloudflare API — the local
`config.yml` is bypassed. To add a public hostname, the tunnel's
`/cfd_tunnel/{id}/configurations` endpoint must be PUT with the new entry
inserted before the catch-all 404 rule.

Adder script (run on Netcup):

```python
import json, os, urllib.request

token = os.environ["CLOUDFLARE_INFRA_TOKEN"]   # from ~/.cloudflare-credentials.env
account = os.environ["CLOUDFLARE_ACCOUNT_ID"]
tunnel = "a838e9dc-0af5-4212-8af2-6864eb15e1b5"
hostname = "pay.jeffemmett.com"

api = f"https://api.cloudflare.com/client/v4/accounts/{account}/cfd_tunnel/{tunnel}/configurations"
cur = json.loads(urllib.request.urlopen(
    urllib.request.Request(api, headers={"Authorization": f"Bearer {token}"})
).read())
cfg = cur["result"]["config"]
if not any(r.get("hostname") == hostname for r in cfg["ingress"]):
    cfg["ingress"].insert(-1, {"service": "http://localhost:80", "hostname": hostname, "originRequest": {}})

urllib.request.urlopen(urllib.request.Request(
    api, data=json.dumps({"config": cfg}).encode(), method="PUT",
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
)).read()
```

DNS CNAME is created separately:

```bash
cloudflared tunnel route dns a838e9dc-0af5-4212-8af2-6864eb15e1b5 pay.jeffemmett.com
```

(Both steps are needed — the CNAME alone returns 404 because the tunnel doesn't
forward unknown hostnames.)

## Status check

```bash
curl https://pay.jeffemmett.com/health   # returns rail catalog
curl https://pay.jeffemmett.com/rails    # full rail list
```

Healthy response:
```json
{
  "status": "ok",
  "version": "0.0.1",
  "rails": [
    {"id": "mock", "kind": "mock"},
    {"id": "x402-base-sepolia", "kind": "x402"},
    {"id": "x402-base", "kind": "x402"},
    {"id": "crdt-iou-base", "kind": "crdt-iou"},
    {"id": "crdt-iou-base-sepolia", "kind": "crdt-iou"}
  ]
}
```

## Uptime Kuma monitor

Spec at `netcup/uptime-kuma/payment-forge-monitor.md`. Manual UI add at
status.jeffemmett.com.

## Eventual Infisical provisioning

When ready to wire real rails:

```bash
export INFISICAL_TOKEN=<org admin>
~/Github/dev-ops/infisical/scripts/create-project.sh payment-forge
```

Then add secrets:
- `X402_DEFAULT_PAYTO` — wallet address for the demo paywall + IOU recipient default
- `BASE_RPC_URL`, `BASE_SEPOLIA_RPC_URL` — for cowswap quote calls
- `COWSWAP_API_KEY` — only if Cowswap requires it (read-only quote endpoint typically doesn't)

Update `.env` on Netcup with the resulting `INFISICAL_CLIENT_ID` + `INFISICAL_CLIENT_SECRET`,
then `docker compose restart payment-forge` to pick up the injected secrets.
