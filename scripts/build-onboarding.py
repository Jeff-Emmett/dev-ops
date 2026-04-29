#!/usr/bin/env python3
"""Bundle the dev-ops onboarding markdown files into a single PDF via doc-forge.

Sources (repo root):
  - AUTO-DEPLOY-BEST-PRACTICES.md
  - SSH-Setup-Guide.md
  - FCDM-DEPLOYMENT-STEPS.md
  - CRYPTO-FIAT-BRIDGE-RESEARCH.md

Output: docs/onboarding.pdf  (title page + TOC + concatenated chapters)

Usage:
  python3 scripts/build-onboarding.py             # writes docs/onboarding.pdf
  python3 scripts/build-onboarding.py --output X  # custom output path
"""
from __future__ import annotations

import argparse
import sys
from datetime import date
from pathlib import Path

THIS = Path(__file__).resolve()
REPO = THIS.parents[1]

SOURCES = [
    "AUTO-DEPLOY-BEST-PRACTICES.md",
    "SSH-Setup-Guide.md",
    "FCDM-DEPLOYMENT-STEPS.md",
    "CRYPTO-FIAT-BRIDGE-RESEARCH.md",
]

DEFAULT_OUTPUT = REPO / "docs" / "onboarding.pdf"


def assemble_markdown() -> str:
    """Concatenate sources with a title block + page-break separators."""
    today = date.today().isoformat()
    parts: list[str] = [
        "---",
        'title: "dev-ops Onboarding Handbook"',
        f'date: "{today}"',
        'subtitle: "Operating notes for jeffemmett.com infrastructure"',
        "toc: true",
        "toc-depth: 2",
        "---",
        "",
    ]
    for src in SOURCES:
        path = REPO / src
        if not path.exists():
            print(f"warning: missing {src}", file=sys.stderr)
            continue
        body = path.read_text(encoding="utf-8")
        # Force a page break before each chapter so the bundled document
        # reads as discrete handbooks rather than one long flowing doc.
        parts.append("\n\\newpage\n")
        parts.append(body.strip())
        parts.append("")
    return "\n".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--output", type=Path, default=DEFAULT_OUTPUT,
                    help=f"output PDF path (default: {DEFAULT_OUTPUT})")
    args = ap.parse_args()

    sys.path.insert(0, str(THIS.parent))
    from docforge_client import convert  # noqa: WPS433

    md = assemble_markdown()
    print(f"assembled {len(md):,} chars from {len(SOURCES)} sources", file=sys.stderr)

    # Two-step conversion: md → docx (pandoc handles cross-references and TOC
    # fields cleanly) → pdf (libreoffice/unoserver expands the TOC and resolves
    # internal links). Direct md → pdf via pandoc-typst chokes on auto-generated
    # cross-doc anchor labels in some of our markdown sources.
    docx_bytes = convert(
        source=("onboarding.md", md.encode("utf-8")),
        to="docx",
        engine="pandoc",
    )
    pdf_bytes = convert(
        source=("onboarding.docx", docx_bytes),
        to="pdf",
        engine="libreoffice",
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(pdf_bytes)
    print(f"wrote {args.output} ({len(pdf_bytes):,} bytes)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
