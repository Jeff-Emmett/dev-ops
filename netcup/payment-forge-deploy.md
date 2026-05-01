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

Update `/opt/services/payment-forge/.env` on Netcup with the resulting `INFISICAL_CLIENT_ID` + `INFISICAL_CLIENT_SECRET`, then `docker compose restart payment-forge` to pick up the injected secrets.

### Env var reference (all optional — rails auto-register only when set)

| Env var | Activates | Source |
|---------|-----------|--------|
| `X402_DEFAULT_PAYTO` | `/demo-paywalled/*` route, IOU recipient default | wallet address |
| `BASE_RPC_URL` | viem PublicClient for bonding-curve rails | Alchemy / Infura / public node |
| `BASE_SEPOLIA_RPC_URL` | viem on testnet | (testnet variant) |
| `COWSWAP_API_KEY` | Cowswap quote API (typically not needed for read-only) | cow.fi |
| `TRANSAK_PARTNER_API_KEY` | `transak-base` rail | transak.com/partner agreement (TASK-78) |
| `TRANSAK_ENVIRONMENT` | `staging` or `production` (default) | — |
| `TRANSAK_ESTIMATED_FEE_BPS` | path-finder fee estimate (default 100) | optional |
| `ONRAMPER_API_KEY` | `onramper-base` rail | onramper.com (TASK-78) |
| `ONRAMPER_ESTIMATED_FEE_BPS` | path-finder fee estimate (default 75) | optional |
| `BITREFILL_API_TOKEN` | `bitrefill-base` rail | bitrefill.com/business/api-access (TASK-79) |
| `BITREFILL_BASE_URL` | API endpoint override | optional |
| `RSPACE_CATALOG_BASE_URL` | `rspace-base` rail | rspace-online deploy (TASK-79 prereq) |
| `GYROSCOPE_RESERVE_BASE` | `gyroscope-base` rail (with GYD + INPUT) | gyro.fi when deployed on Base |
| `GYROSCOPE_GYD_BASE` | (with above) | GYD token address |
| `GYROSCOPE_INPUT_BASE` | (with above) | typically USDC |
| `ERC4626_VAULTS_JSON` | one `erc4626-base-<idSuffix>` rail per entry | Morpho / Yearn / Aave v3 vaults |
| `MYCO_VAULT_ADDRESS_BASE` | `myco-base` rail (on-chain path) | $MYCO contract once deployed (TASK-80) |
| `MYCO_ASSET_ADDRESS_BASE` | (with above) | underlying token, typically USDC |
| `MYCO_HTTP_ENDPOINT` | `myco-base` rail (HTTP path) | simulate.rspace.online/api once REST surface ships |

### `ERC4626_VAULTS_JSON` shape

```json
[
  {"chain":"base","address":"0x...","idSuffix":"morpho-usdc","slippageBps":10},
  {"chain":"base","address":"0x...","idSuffix":"yearn-usdc"}
]
```

`slippageBps` defaults to 0; `assetAddress` is fetched via `vault.asset()` if omitted.

### Activation order

The rails fall into four families with separate prerequisites:

1. **TASK-77** — core deploy: `X402_DEFAULT_PAYTO`, `BASE_RPC_URL`, `BASE_SEPOLIA_RPC_URL`
2. **TASK-78** — fiat: `TRANSAK_PARTNER_API_KEY`, `ONRAMPER_API_KEY`
3. **TASK-79** — redemption: `BITREFILL_API_TOKEN`, `RSPACE_CATALOG_BASE_URL`
4. **TASK-80** — bonding curves: Gyroscope addresses, `ERC4626_VAULTS_JSON`, `MYCO_*`

Each family activates independently — no need to wait for the full set.
