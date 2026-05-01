# funion-sidecar — Netcup deployment

Two open-weights LLM sidecars running on Netcup CPU, fronting an
OpenAI-compatible HTTP endpoint that LiteLLM proxies into the funion
stack.

| Service | Model | Port | RAM (loaded) | CPU tok/s |
|---|---|---|---|---|
| `funion-sidecar` | Phi-3-mini-4k-instruct Q4_K_M | 9100 | ~1.55 GiB | ~1.5 |
| `funion-sidecar-llama3` | Llama-3.1-8B-Instruct Q4_K_M | 9100 | ~4.58 GiB | ~0.6 |

Both run from the same image (`funion-sidecar:llamacpp`) built from
the local `Dockerfile`. They live on the `ai-internal` docker network
so LiteLLM reaches them by service name (`http://funion-sidecar:9100`,
`http://funion-sidecar-llama3:9100`). No public Cloudflare exposure.

## Layout on Netcup

```
/opt/apps/funion-sidecar/
├── Dockerfile                 # python:3.11 + cmake + llama-cpp-python==0.3.2
├── docker-compose.yml         # both services
├── .env                       # FUNION_SIDECAR_TOKEN (chmod 600, NOT committed)
├── sidecar/                   # source mirrored from zknet-labs-src/src/core/compute-courier/sidecar/
│   └── main.py
├── models/
│   ├── Phi-3-mini-4k-instruct-q4.gguf                  # ~2.3 GiB
│   ├── Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf          # ~4.6 GiB
│   └── tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf            # legacy, kept for fallback
└── README.md
```

## Source of truth

| File | Lives in repo | Mirrored to Netcup as |
|---|---|---|
| `sidecar/main.py` | `zknet-labs-src/src/core/compute-courier/sidecar/main.py` | `/opt/apps/funion-sidecar/sidecar/main.py` |
| `Dockerfile` | here in `dev-ops/netcup/funion-sidecar/` | `/opt/apps/funion-sidecar/Dockerfile` |
| `docker-compose.yml` | here in `dev-ops/netcup/funion-sidecar/` | `/opt/apps/funion-sidecar/docker-compose.yml` |
| `.env` | NOT in repo (chmod 600 secret) | `/opt/apps/funion-sidecar/.env` |
| GGUF weights | NOT in repo (huge binaries) | `/opt/apps/funion-sidecar/models/` |

When the sidecar Python code changes upstream, sync it to Netcup:

```sh
cat ~/Github/zknet-labs-src/src/core/compute-courier/sidecar/main.py \
  | ssh netcup-full 'cat > /opt/apps/funion-sidecar/sidecar/main.py'
ssh netcup-full 'chown 1000:1000 /opt/apps/funion-sidecar/sidecar/main.py && \
  cd /opt/apps/funion-sidecar && docker compose restart'
```

When `docker-compose.yml` or `Dockerfile` changes here, push them:

```sh
scp -3 docker-compose.yml netcup-full:/opt/apps/funion-sidecar/
ssh netcup-full 'cd /opt/apps/funion-sidecar && docker compose up -d'
```

## Token

Required env var: `FUNION_SIDECAR_TOKEN` (32+ hex chars, chmod 600).
Same value lives in `/opt/apps/litellm/.env` so LiteLLM's
`funion-phi3` / `funion-llama-3-8b` model entries can pass auth.

## Smoke (from Netcup, internal)

```sh
ssh netcup-full
TOK=$(grep FUNION_SIDECAR_TOKEN /opt/apps/funion-sidecar/.env | cut -d= -f2)
docker exec litellm sh -c "
KEY=\$(tr '\\0' '\\n' < /proc/1/environ | grep ^LITELLM_MASTER_KEY= | cut -d= -f2)
python3 -c \"
import urllib.request, json, os
key = '\$KEY'
body = json.dumps({'model': 'funion-phi3', 'messages': [{'role':'user','content':'hello'}], 'max_tokens': 30}).encode()
req = urllib.request.Request('http://127.0.0.1:4000/v1/chat/completions', data=body, headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'})
print(urllib.request.urlopen(req, timeout=120).read().decode())
\"
"
```

## Capacity reality

Total funion footprint on Netcup: ~6.1 GiB working set. Netcup has
~10 GiB free at deploy time (out of 62 GiB total). Adding a third
heavy CPU model (e.g. Llama-3.1-70B Q4 ~42 GB) would not fit.
Heavyweight tier 3 lives on RunPod serverless — see
`dev-ops/runpod/funion-qwen-coder/README.md` (M5).

## Build the image (first time)

```sh
ssh netcup-full
cd /opt/apps/funion-sidecar
docker build -t funion-sidecar:llamacpp .
# ~3-4 min on first build (compiles llama-cpp-python from source)
```

Re-build only when the Dockerfile changes; pip pin
`llama-cpp-python==0.3.2` keeps cache warm.

## Operations

```sh
ssh netcup-full
cd /opt/apps/funion-sidecar
docker compose ps
docker compose up -d                    # start
docker compose logs -f funion-sidecar
docker stats funion-sidecar funion-sidecar-llama3
```

Restart on Python change:

```sh
docker compose restart funion-sidecar funion-sidecar-llama3
# wait ~5-10s for the model to reload
```

Force-recreate (rare; required when env vars or compose changes):

```sh
docker compose up -d --force-recreate
```

## Adding a new model

1. Pull the GGUF to `/opt/apps/funion-sidecar/models/`
2. Add a new service block in `docker-compose.yml` (copy from
   `funion-sidecar-llama3`, change container name, port, model-id,
   model-path, mem_limit, cpus)
3. Add a corresponding entry in `dev-ops/netcup/litellm/config.yaml`
   pointing at the new container's hostname
4. Add a row in `funion-mcp` `modelCatalogue`
   (`zknet-labs-src/src/core/funion-mcp/cmd/funion-mcp/main.go`)
5. Rebuild funion-mcp and update `~/bin/funion-mcp`
6. `docker compose up -d` on Netcup, restart LiteLLM

## Backlog references

- M1 Phi-3-mini deploy: funion-rollout TASK-002 (done)
- M2 LiteLLM funion-phi3: TASK-003 (done)
- M3 Llama-3.1-8B deploy: TASK-004 (done)
- M5 RunPod tier 3: TASK-006 (prep complete; deploy gated on Jeff)
- M6 mixnet via_mixnet flag: TASK-007 (design complete; impl gated on
  upstream Katzenpost stability)
