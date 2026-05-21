# GX10 benchmark harness — TASK-91

Measures the **inference layer** across endpoints: TTFT, decode throughput,
context scaling, and multimodal latency.

## Setup

```bash
cd gx10/benchmark
python -m venv .venv && . .venv/bin/activate
pip install requests
cp endpoints.example.json endpoints.json   # then fill in IPs + keys
```

## Run

```bash
python harness.py                  # text suite, all endpoints, 2 runs each
python harness.py --runs 3         # more samples, reports the median
python harness.py --image shot.png # adds the multimodal probe (gx10-vl)
```

Results: `results/results-<timestamp>.{json,md}` (gitignored).

## What it covers — and what it does not

Covered: `short`, `coding`, `ctx_4k`, `ctx_32k`, and an optional `multimodal`
prompt → TTFT, decode tok/s, total latency per endpoint.

**Not** covered (measure separately for TASK-91):
- **Agent-loop wall-clock** — time OpenCode to finish a fixed task list, once
  in a Docker SBX microVM and once native on the GX10. The harness benchmarks
  the model server, not the agent.
- **microVM overhead** — `sbx` boot + FS-mount time.
- **Power draw / $ per task** — wall meter; RunPod billing.

Pin the same Qwen3-VL model + quant on every endpoint first, or the numbers
compare models instead of platforms (TASK-91 AC#6).
