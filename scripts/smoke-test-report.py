#!/usr/bin/env python3
"""Render a PDF report of the latest smoke-test results via doc-forge.

Reads `smoke-tests/logs/{site}_{timestamp}_{PASS|FAIL}.log`, picks the most
recent run per site, and produces a one-page-ish summary PDF: pass/fail
table + selected output for any failing sites.

Usage:
  python3 scripts/smoke-test-report.py
  python3 scripts/smoke-test-report.py --output /tmp/smoke-report.pdf
"""
from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path

THIS = Path(__file__).resolve()
REPO = THIS.parents[1]
LOG_DIR = REPO / "smoke-tests" / "logs"

LOG_RE = re.compile(r"^(?P<site>.+?)_(?P<ts>\d{8}_\d{6})_(?P<status>PASS|FAIL)\.log$")
DEFAULT_OUTPUT = Path("/tmp/smoke-test-report.pdf")


def parse_log_filename(name: str):
    m = LOG_RE.match(name)
    if not m:
        return None
    return {
        "site": m["site"],
        "timestamp": datetime.strptime(m["ts"], "%Y%m%d_%H%M%S"),
        "status": m["status"],
    }


def latest_per_site(log_dir: Path) -> dict:
    """Return {site: {timestamp, status, path}} for the most recent log per site."""
    latest: dict[str, dict] = {}
    for f in log_dir.glob("*.log"):
        meta = parse_log_filename(f.name)
        if not meta:
            continue
        cur = latest.get(meta["site"])
        if cur is None or meta["timestamp"] > cur["timestamp"]:
            latest[meta["site"]] = {**meta, "path": f}
    return latest


def assemble_markdown(latest: dict) -> str:
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    sites = sorted(latest.values(), key=lambda r: (r["status"] == "PASS", r["site"]))
    failures = [r for r in sites if r["status"] == "FAIL"]
    passes = [r for r in sites if r["status"] == "PASS"]

    parts = [
        "---",
        'title: "Smoke Test Report"',
        f'subtitle: "{now} — {len(passes)} pass, {len(failures)} fail, {len(sites)} total"',
        "---",
        "",
        "# Summary",
        "",
        f"| Site | Last Run | Status |",
        f"|------|----------|--------|",
    ]
    for r in sites:
        ts = r["timestamp"].strftime("%Y-%m-%d %H:%M")
        marker = "PASS" if r["status"] == "PASS" else "FAIL"
        parts.append(f"| {r['site']} | {ts} | **{marker}** |")
    parts.append("")

    if failures:
        parts.append("# Failures")
        parts.append("")
        for r in failures:
            parts.append(f"## {r['site']}")
            parts.append("")
            log_text = r["path"].read_text(encoding="utf-8", errors="replace")
            # Trim to last ~60 lines so the report stays readable.
            tail = "\n".join(log_text.splitlines()[-60:])
            parts.append("```")
            parts.append(tail)
            parts.append("```")
            parts.append("")
    return "\n".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--output", type=Path, default=DEFAULT_OUTPUT,
                    help=f"output PDF path (default: {DEFAULT_OUTPUT})")
    args = ap.parse_args()

    if not LOG_DIR.is_dir():
        print(f"log dir not found: {LOG_DIR}", file=sys.stderr)
        return 1

    sys.path.insert(0, str(THIS.parent))
    from docforge_client import convert  # noqa: WPS433

    latest = latest_per_site(LOG_DIR)
    if not latest:
        print("no parseable logs found", file=sys.stderr)
        return 2
    md = assemble_markdown(latest)
    print(f"summarized {len(latest)} sites", file=sys.stderr)

    docx_bytes = convert(("smoke.md", md.encode("utf-8")), to="docx", engine="pandoc")
    pdf_bytes = convert(("smoke.docx", docx_bytes), to="pdf", engine="libreoffice")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(pdf_bytes)
    print(f"wrote {args.output} ({len(pdf_bytes):,} bytes)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
