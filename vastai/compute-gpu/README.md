# compute-gpu — Vast.ai GPU executor for Compute-Morpheus

> **Secondary burst tier.** Vast.ai analogue of `dev-ops/runpod/compute-gpu/`.
> Vast undercuts RunPod ~20–40% on $/hr at the A5000 / RTX 4090 / L4 / A100
> class this executor uses. rspace dispatch
> (`shared/morpheus/forges/compute-forge.ts`) **cost-ranks every announced
> executor**, so a cheaper Vast executor automatically wins routing — there is
> no router priority to set. "Secondary" just means: spin Vast by default,
> keep `runpod/` as fallback.

## Why this is scripting-only (no rspace code change)

The executor image (`rspace-online/docker/compute-gpu/`), `server.py`,
`announce.py`, and the cost-ranked dispatch are **provider-agnostic**. The
only RunPod-specific code lived in `up.sh`/`boot.sh`. Two facts make Vast a
drop-in:

1. `server.py:52` already honours `COMPUTE_GPU_PUBLIC_ENDPOINT` (added for
   "Tailscale / custom DNS"). RunPod auto-derives a `*.proxy.runpod.net` URL
   from `RUNPOD_POD_ID`; Vast has no such proxy, so `boot.sh` sets the override
   to the instance's **tailnet IP** instead.
2. Dispatch ranks by advertised `dollarsPerOp` — same `ExecutorCapability`
   shape for both providers.

## Files

| File | Role |
|---|---|
| `up.sh` | Find cheapest reliable Vast offer (`vastai search offers`), create instance, wait for announce. |
| `boot.sh` | On-start (runs inside the executor image): install + join Tailscale, set `COMPUTE_GPU_PUBLIC_ENDPOINT`, `exec python3 server.py`. **No docker-in-docker.** |
| `down.sh` | Drain (`mark-dead`) then `vastai destroy instance`. `--all` clears every `rspace-compute-gpu`-labelled instance. |
| `status.sh` | Instance state + rspace pool membership. |

## Prerequisites (one-time)

1. **Vast API key** — already at `~/.secrets/private/vastai_api_key`
   (tracked in `security/secrets-inventory.yaml`, rotation runbook
   `security/runbook-external-api-key.md`). Or export `VASTAI_API_KEY`.
2. **`vastai` CLI** — installed at `~/.local/bin/vastai` (v0.5.0).
3. **Tailscale auth key** — mint an **ephemeral** key tagged `tag:vastai`
   in the Tailscale admin console; export as `TAILSCALE_AUTHKEY`. This is
   **mandatory** on Vast: rspace (on Netcup, on the tailnet) calls the
   executor back at `http://<tailnet-ip>:9101/execute`.
4. Executor image `ghcr.io/jeff-emmett/rspace-compute-gpu:latest` must be
   **public** (same one-time flip as the RunPod path).

## Usage

```bash
export TAILSCALE_AUTHKEY='tskey-auth-...'      # ephemeral, tag:vastai

./up.sh                       # cheapest RTX_4090 under $0.35/hr
./up.sh RTX_A5000 0.15        # cheaper A5000 tier
./up.sh A100_PCIE 0.80        # bigger LLM-class GPU

./status.sh                   # instance + rspace pool
./down.sh                     # drain + destroy this instance
./down.sh --all               # destroy all rspace-compute-gpu instances
```

## Cost (interruptible, Jun 2026)

| GPU | Vast (this script) | RunPod community | Save |
|---|---|---|---|
| RTX A5000 24GB | ~$0.10–0.13/hr | ~$0.16/hr | ~30% |
| RTX 4090 24GB | ~$0.22–0.31/hr | ~$0.34/hr | ~25% |
| L4 24GB | ~$0.30–0.40/hr | ~$0.44/hr | ~20% |
| A100 80GB | ~$0.67/hr | ~$0.79/hr | ~15% |

Off-prem → `public` + `internal` sensitivity tiers only (the `secret`/
`confidential` gating in `server.py` rejects sensitive plans here — same as
RunPod).

## Gotchas

- **Userspace Tailscale**: `boot.sh` uses `--tun=userspace-networking` (no
  `/dev/net/tun` needed). Most Vast offers allow it; if `up.sh` times out at
  the announce step, check `vastai logs <id>` — a host that blocks outbound
  Tailscale (UDP 41641 / DERP 443) is the usual cause. Pick another offer.
- **Slower first announce than RunPod** (~30–60s extra): the on-start
  `apt-get install curl` + Tailscale install runs before the server starts.
  `up.sh` waits up to 7 min.
- **Marketplace variability**: an offer can vanish or a host can be flaky.
  That's the price of the ~25% saving — for an interruptible, cleanly-draining
  burst executor it's acceptable. Fall back to `runpod/compute-gpu/up.sh` if
  Vast availability is thin.
- **`-o dph` sort**: `up.sh` takes the cheapest offer meeting
  `reliability>0.98 inet_down>200 cuda_max_good>=12.4`. Loosen via the
  `MAX_DPH` arg, not by dropping the reliability floor.
