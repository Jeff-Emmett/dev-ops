# GX10 — ASUS Ascent GX10 node

Provisioning + integration for the **ASUS Ascent GX10** (NVIDIA GB10 Grace
Blackwell, 128 GB unified LPDDR5x, DGX OS / ARM64) as the **primary heavy
compute tier** for all local-AI workloads.

## Architecture decision (2026-05-21)

The dev environment already offloads *everything* over Tailscale to a LiteLLM
router on Netcup. The GX10 is **not a new architecture** — it is a new compute
tier slotted into that pattern:

```
clients (OpenCode, aider, funion-run, MCP)
   │  Tailscale
   ▼
GX10 LiteLLM  ──primary──►  GX10 Ollama (Qwen3-VL / Qwen3-Coder, 128 GB)
   │
   ├─ fallback ─►  RunPod vLLM (GPU burst — demoted to overflow only)
   ├─ fallback ─►  Netcup CPU Ollama (always-on tiny tier)
   └─ fallback ─►  cloud (Claude / Gemini, paid)

Netcup LiteLLM stays up as an independent fallback router.
```

Confirmed facts that shaped this:
- The WSL2 dev box has **no usable NVIDIA GPU** — no local-model tier there.
- **Docker Sandbox microVMs have no GPU passthrough** — agents run sandboxed,
  the model always runs on the GX10.
- The GX10 has 128 GB unified memory — **GreenBoost is N/A** (nothing to spill).

## Layout

| Path | Purpose |
|------|---------|
| `litellm/` | GX10-hosted LiteLLM router — config, compose, env template |
| `ansible/` | `provision-gx10.yml` playbook — run on first boot |
| `opencode/` | OpenCode provider config pointed at the GX10 LiteLLM |
| `benchmark/` | TASK-91 benchmark harness (TTFT / tok/s / multimodal) |

## Bring-up order (when the GX10 arrives)

1. Boot the GX10, complete DGX OS setup.
2. `ansible-playbook -i ansible/inventory.ini ansible/provision-gx10.yml`
   (joins Tailscale, configures Ollama, pulls models, deploys LiteLLM, UFW).
3. Note the GX10's Tailscale IP; fill it into `opencode/opencode.json` and
   `benchmark/endpoints.json`.
4. Apply `opencode/opencode.json` to `~/.config/opencode/opencode.json`.
5. Add a `gx10-*` reference to the Netcup LiteLLM config so server-side
   consumers can reach it too.
6. Run `benchmark/harness.py` — populate TASK-91.

See TASK-91 in Backlog for the benchmark plan.
