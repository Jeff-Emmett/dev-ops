#!/usr/bin/env python3
"""GX10 benchmark harness — TASK-91.

Drives a fixed prompt suite against one or more OpenAI-compatible endpoints
and measures TTFT, decode throughput, and multimodal latency. Use it to
compare the GX10 LiteLLM router against fallback tiers (Netcup, RunPod) and
to populate the TASK-91 decision matrix.

Endpoints are defined in endpoints.json (gitignored — see endpoints.example.json):

    [
      {"label": "gx10",   "base_url": "http://GX10_IP:4000/v1",
       "model": "gx10-coder", "api_key": "..."},
      {"label": "netcup", "base_url": "http://100.64.0.2:4000/v1",
       "model": "qwen3-coder", "api_key": "..."}
    ]

Usage:
    python harness.py                       # text suite, all endpoints
    python harness.py --image shot.png      # also run the multimodal probe
    python harness.py --runs 3              # average over N runs per prompt

Results land in results/results-<timestamp>.{json,md}.
"""
from __future__ import annotations

import argparse
import base64
import json
import statistics
import sys
import time
from datetime import datetime
from pathlib import Path

import requests

HERE = Path(__file__).parent
RESULTS_DIR = HERE / "results"

# --- Prompt suite -----------------------------------------------------------
# Context is padded with filler to hit target sizes; the real instruction is
# always appended last so the model answers the same question every time.
_FILLER = ("The quick brown fox jumps over the lazy dog. " * 24).strip()


def _padded(target_words: int, question: str) -> str:
    pad, n = [], 0
    while n < target_words:
        pad.append(_FILLER)
        n += _FILLER.count(" ") + 1
    return ("Reference material (ignore for the answer):\n"
            + "\n".join(pad) + f"\n\nTask: {question}")


TEXT_SUITE = {
    "short":   "Write a haiku about distributed systems.",
    "coding":  "Implement a thread-safe LRU cache with per-entry TTL in Python. "
               "Return only the code.",
    "ctx_4k":  _padded(3000, "Summarize the reference material in one sentence."),
    "ctx_32k": _padded(24000, "Summarize the reference material in one sentence."),
}

MULTIMODAL_QUESTION = "Describe this image in detail and transcribe any text you see."


def load_endpoints() -> list[dict]:
    path = HERE / "endpoints.json"
    if not path.is_file():
        sys.exit(f"missing {path} — copy endpoints.example.json and fill it in")
    return json.loads(path.read_text())


def build_messages(prompt: str, image_path: str | None) -> list[dict]:
    if image_path:
        b64 = base64.b64encode(Path(image_path).read_bytes()).decode()
        return [{"role": "user", "content": [
            {"type": "text", "text": prompt},
            {"type": "image_url",
             "image_url": {"url": f"data:image/png;base64,{b64}"}},
        ]}]
    return [{"role": "user", "content": prompt}]


def run_once(ep: dict, messages: list[dict]) -> dict:
    """Stream one completion; return timing + token metrics (or an error)."""
    url = ep["base_url"].rstrip("/") + "/chat/completions"
    headers = {"Content-Type": "application/json"}
    if ep.get("api_key"):
        headers["Authorization"] = f"Bearer {ep['api_key']}"
    body = {
        "model": ep["model"],
        "messages": messages,
        "stream": True,
        "stream_options": {"include_usage": True},
        "max_tokens": 1024,
        "temperature": 0.2,
    }

    t0 = time.perf_counter()
    ttft = None
    chunk_tokens = 0
    usage_tokens = None
    try:
        with requests.post(url, headers=headers, json=body,
                           stream=True, timeout=600) as r:
            r.raise_for_status()
            for line in r.iter_lines(decode_unicode=True):
                if not line or not line.startswith("data: "):
                    continue
                payload = line[6:]
                if payload == "[DONE]":
                    break
                data = json.loads(payload)
                if data.get("usage"):
                    usage_tokens = data["usage"].get("completion_tokens")
                for choice in data.get("choices", []):
                    delta = choice.get("delta", {}).get("content")
                    if delta:
                        if ttft is None:
                            ttft = time.perf_counter() - t0
                        chunk_tokens += 1
    except Exception as exc:  # noqa: BLE001 — report, don't crash the suite
        return {"error": f"{type(exc).__name__}: {exc}"}

    total = time.perf_counter() - t0
    tokens = usage_tokens or chunk_tokens
    decode_window = max(total - (ttft or 0), 1e-6)
    return {
        "ttft_ms": round((ttft or total) * 1000, 1),
        "total_ms": round(total * 1000, 1),
        "tokens": tokens,
        "decode_tok_s": round(tokens / decode_window, 1),
    }


def aggregate(samples: list[dict]) -> dict:
    ok = [s for s in samples if "error" not in s]
    if not ok:
        return {"error": samples[0].get("error", "all runs failed")}
    return {
        "ttft_ms": round(statistics.median(s["ttft_ms"] for s in ok), 1),
        "decode_tok_s": round(statistics.median(s["decode_tok_s"] for s in ok), 1),
        "total_ms": round(statistics.median(s["total_ms"] for s in ok), 1),
        "tokens": round(statistics.median(s["tokens"] for s in ok)),
        "runs": len(ok),
    }


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="GX10 benchmark harness (TASK-91)")
    ap.add_argument("--image", help="image file → adds the multimodal probe")
    ap.add_argument("--runs", type=int, default=2, help="runs per prompt (median)")
    args = ap.parse_args(argv)

    endpoints = load_endpoints()
    suite = dict(TEXT_SUITE)
    if args.image:
        suite["multimodal"] = MULTIMODAL_QUESTION

    results: dict = {}
    for ep in endpoints:
        label = ep["label"]
        results[label] = {}
        print(f"\n=== {label}  ({ep['model']} @ {ep['base_url']}) ===")
        for name, prompt in suite.items():
            img = args.image if name == "multimodal" else None
            messages = build_messages(prompt, img)
            samples = [run_once(ep, messages) for _ in range(args.runs)]
            agg = aggregate(samples)
            results[label][name] = agg
            if "error" in agg:
                print(f"  {name:12} ERROR: {agg['error']}")
            else:
                print(f"  {name:12} TTFT {agg['ttft_ms']:>8} ms   "
                      f"{agg['decode_tok_s']:>6} tok/s   "
                      f"{agg['total_ms']:>8} ms total")

    RESULTS_DIR.mkdir(exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    (RESULTS_DIR / f"results-{ts}.json").write_text(json.dumps(results, indent=2))
    (RESULTS_DIR / f"results-{ts}.md").write_text(render_md(results, suite))
    print(f"\nWritten: results/results-{ts}.json  +  .md")
    return 0


def render_md(results: dict, suite: dict) -> str:
    lines = [f"# GX10 benchmark — {datetime.now():%Y-%m-%d %H:%M}", ""]
    for name in suite:
        lines += [f"## {name}", "",
                  "| Endpoint | TTFT (ms) | Decode (tok/s) | Total (ms) |",
                  "|---|--:|--:|--:|"]
        for label, runs in results.items():
            r = runs.get(name, {})
            if "error" in r:
                lines.append(f"| {label} | — | — | {r['error']} |")
            else:
                lines.append(f"| {label} | {r['ttft_ms']} | "
                              f"{r['decode_tok_s']} | {r['total_ms']} |")
        lines.append("")
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
