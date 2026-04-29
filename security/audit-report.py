#!/usr/bin/env python3
"""Render a PDF audit report from secrets-inventory.yaml via doc-forge.

Pairs with `check-rotation-due.sh` (which emails a plain-text digest). This
produces a richer artifact: full inventory table grouped by category, due/
overdue/ok counts, and a per-secret detail block.

Usage:
  python3 audit-report.py
  python3 audit-report.py --output /tmp/secrets-audit.pdf
  python3 audit-report.py --warn-days 30
"""
from __future__ import annotations

import argparse
import datetime as dt
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML required (pip install pyyaml)", file=sys.stderr)
    raise SystemExit(1)

THIS = Path(__file__).resolve()
REPO = THIS.parents[1]
INVENTORY = THIS.parent / "secrets-inventory.yaml"
DEFAULT_OUTPUT = Path("/tmp/secrets-audit.pdf")


def classify(secret: dict, today: dt.date, warn_days: int) -> tuple[str, int | None]:
    cadence = int(secret.get("cadence_days", 365))
    last = secret.get("last_rotated")
    if not last:
        return ("never-rotated", None)
    last_d = last if isinstance(last, dt.date) else dt.date.fromisoformat(str(last))
    next_due = last_d + dt.timedelta(days=cadence)
    days_left = (next_due - today).days
    if days_left < 0:
        return ("overdue", days_left)
    if days_left <= warn_days:
        return ("due-soon", days_left)
    return ("ok", days_left)


def location_str(secret: dict) -> str:
    loc = secret.get("location", {})
    t = loc.get("type", "?")
    if t == "file":
        return f"{loc.get('server', '?')}:{loc.get('path', '?')}"
    if t == "infisical":
        return f"infisical {loc.get('project', '?')}{loc.get('path', '')}"
    if t == "external":
        return f"external — {loc.get('description', '?')}"
    return t


def assemble_markdown(data: dict, warn_days: int) -> str:
    today = dt.date.today()
    secrets = data.get("secrets", [])
    classified = [(s, *classify(s, today, warn_days)) for s in secrets]

    counts = {"overdue": 0, "due-soon": 0, "ok": 0, "never-rotated": 0}
    for _, status, _ in classified:
        counts[status] += 1

    parts = [
        "---",
        'title: "Secrets Rotation Audit"',
        f'subtitle: "{today.isoformat()} — {len(secrets)} secrets tracked"',
        "---",
        "",
        "# Summary",
        "",
        f"| Status | Count |",
        f"|--------|------:|",
        f"| Overdue        | {counts['overdue']} |",
        f"| Due soon (≤{warn_days}d) | {counts['due-soon']} |",
        f"| OK             | {counts['ok']} |",
        f"| Never rotated  | {counts['never-rotated']} |",
        "",
        "# Inventory",
        "",
        "| Name | Category | Location | Cadence | Last rotated | Status |",
        "|------|----------|----------|--------:|--------------|--------|",
    ]
    status_label = {
        "overdue": "OVERDUE",
        "due-soon": "due soon",
        "ok": "ok",
        "never-rotated": "never rotated",
    }
    # Sort: overdue first, then due-soon, never-rotated, then ok.
    sort_order = {"overdue": 0, "due-soon": 1, "never-rotated": 2, "ok": 3}
    classified.sort(key=lambda r: (sort_order[r[1]], r[0].get("name", "")))
    for s, status, days in classified:
        last = s.get("last_rotated", "—")
        cadence = s.get("cadence_days", "—")
        status_text = status_label[status]
        if days is not None and status in ("overdue", "due-soon"):
            status_text += f" ({days:+d}d)"
        parts.append(
            f"| {s.get('name', '?')} "
            f"| {s.get('category', '?')} "
            f"| {location_str(s)} "
            f"| {cadence} "
            f"| {last} "
            f"| {status_text} |"
        )

    # Detail blocks for anything overdue or never-rotated.
    flagged = [r for r in classified if r[1] in ("overdue", "never-rotated", "due-soon")]
    if flagged:
        parts.extend(["", "# Action Required", ""])
        for s, status, days in flagged:
            parts.append(f"## {s.get('name', '?')} — {status_label[status]}")
            parts.append("")
            parts.append(f"- **Description:** {s.get('description', '—')}")
            parts.append(f"- **Location:** {location_str(s)}")
            rotation = s.get("rotation", {})
            mode = rotation.get("mode", "?")
            ref = rotation.get("script") or rotation.get("runbook") or "—"
            parts.append(f"- **Rotation:** {mode} ({ref})")
            consumers = s.get("consumers", [])
            if consumers:
                parts.append("- **Consumers:**")
                for c in consumers:
                    parts.append(
                        f"    - {c.get('service', c.get('kind', '?'))}"
                        f" — {c.get('action', '—')}"
                    )
            if s.get("notes"):
                parts.append(f"- **Notes:** {s['notes']}")
            parts.append("")
    return "\n".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--output", type=Path, default=DEFAULT_OUTPUT,
                    help=f"output PDF path (default: {DEFAULT_OUTPUT})")
    ap.add_argument("--warn-days", type=int, default=14,
                    help="days-out window to flag a secret as 'due soon' (default: 14)")
    ap.add_argument("--inventory", type=Path, default=INVENTORY)
    args = ap.parse_args()

    if not args.inventory.exists():
        print(f"inventory not found: {args.inventory}", file=sys.stderr)
        return 1

    sys.path.insert(0, str(REPO / "scripts"))
    from docforge_client import convert  # noqa: WPS433

    data = yaml.safe_load(args.inventory.read_text(encoding="utf-8"))
    md = assemble_markdown(data, args.warn_days)

    docx_bytes = convert(("audit.md", md.encode("utf-8")), to="docx", engine="pandoc")
    pdf_bytes = convert(("audit.docx", docx_bytes), to="pdf", engine="libreoffice")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(pdf_bytes)
    print(f"wrote {args.output} ({len(pdf_bytes):,} bytes)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
