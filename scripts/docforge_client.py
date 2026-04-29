#!/usr/bin/env python3
"""Shared client for the doc-forge document conversion service.

Wraps the multipart POST to https://convert.jeffemmett.com/convert with
optional sibling assets so callers don't re-implement the boilerplate.

Engines and supported formats are queried from /formats. The service runs
LibreOffice (via unoserver), Tectonic, Typst, and Pandoc behind a single
endpoint; the right engine is auto-selected from the input/output formats.

Usage::

    from docforge_client import convert, ConvertError

    pdf_bytes = convert(
        source=Path("book.typ"),
        to="pdf",
        assets=[Path("art/cover.jpg"), Path("art/footer.jpg")],
    )
    Path("book.pdf").write_bytes(pdf_bytes)

Or pass bytes directly::

    pdf_bytes = convert(
        source=("doc.md", b"# Hello\\n\\nWorld."),
        to="pdf",
        engine="pandoc",
    )

Environment:
    DOCFORGE_URL  override the default endpoint
"""
from __future__ import annotations

import os
from pathlib import Path
from typing import Iterable, Sequence

import httpx

DEFAULT_URL = os.environ.get("DOCFORGE_URL", "https://convert.jeffemmett.com")
DEFAULT_TIMEOUT = 300.0

SourceArg = "Path | tuple[str, bytes]"
AssetArg = "Path | tuple[str, bytes]"


class ConvertError(RuntimeError):
    """Raised when doc-forge returns a non-200 status."""

    def __init__(self, status: int, body: str) -> None:
        super().__init__(f"doc-forge convert failed [{status}]: {body[:500]}")
        self.status = status
        self.body = body


def _to_multipart(label: str, item) -> tuple[str, tuple[str, bytes, str]]:
    """Normalize a Path or (name, bytes) tuple to httpx multipart form."""
    if isinstance(item, Path):
        return (label, (item.name, item.read_bytes(), "application/octet-stream"))
    name, data = item
    return (label, (name, data, "application/octet-stream"))


def convert(
    source,
    to: str,
    assets: Sequence = (),
    engine: str | None = None,
    url: str = DEFAULT_URL,
    timeout: float = DEFAULT_TIMEOUT,
) -> bytes:
    """Convert ``source`` to ``to`` format and return the result bytes.

    ``source``  Path or (filename, bytes). The filename's extension drives
                engine selection unless ``engine`` is set explicitly.
    ``to``      Target extension (e.g. ``"pdf"``, ``"epub"``, ``"docx"``).
    ``assets``  Optional sibling files needed by the source (Typst images,
                LaTeX includegraphics, etc.). Each is Path or (name, bytes).
    ``engine``  Force a specific engine (``"libreoffice"``, ``"tectonic"``,
                ``"typst"``, ``"pandoc"``). Default: auto-select.
    """
    files = [_to_multipart("file", source)]
    files.extend(_to_multipart("assets", a) for a in assets)
    data = {"to": to}
    if engine:
        data["engine"] = engine
    r = httpx.post(f"{url}/convert", files=files, data=data, timeout=timeout)
    if r.status_code != 200:
        raise ConvertError(r.status_code, r.text)
    return r.content


def health(url: str = DEFAULT_URL, timeout: float = 10.0) -> dict:
    """Return the /health JSON document."""
    r = httpx.get(f"{url}/health", timeout=timeout)
    r.raise_for_status()
    return r.json()


def formats(url: str = DEFAULT_URL, timeout: float = 10.0) -> dict:
    """Return the /formats JSON document (engines + their input/output sets)."""
    r = httpx.get(f"{url}/formats", timeout=timeout)
    r.raise_for_status()
    return r.json()


# ---------------------------------------------------------------------------
# CLI: `python docforge_client.py SRC DST [--asset PATH ...] [--engine NAME]`
# ---------------------------------------------------------------------------

def _main() -> int:
    import argparse

    ap = argparse.ArgumentParser(description="doc-forge thin CLI")
    ap.add_argument("src", type=Path, help="source file path")
    ap.add_argument("dst", type=Path, help="destination file path (extension drives target format)")
    ap.add_argument("--asset", type=Path, action="append", default=[],
                    help="sibling asset file (repeatable)")
    ap.add_argument("--engine", default=None,
                    help="force engine: libreoffice|tectonic|typst|pandoc")
    ap.add_argument("--url", default=DEFAULT_URL)
    args = ap.parse_args()

    target = args.dst.suffix.lstrip(".").lower()
    if not target:
        ap.error("destination must have an extension")

    out = convert(
        source=args.src,
        to=target,
        assets=args.asset,
        engine=args.engine,
        url=args.url,
    )
    args.dst.write_bytes(out)
    print(f"wrote {args.dst} ({len(out):,} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
