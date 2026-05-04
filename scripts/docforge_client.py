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


def list_templates(url: str = DEFAULT_URL, timeout: float = 10.0) -> list[dict]:
    """Return the registered design templates (id + schema for each)."""
    r = httpx.get(f"{url}/templates", timeout=timeout)
    r.raise_for_status()
    return r.json().get("templates", [])


def template_preview(
    template: str,
    ppi: int = 72,
    url: str = DEFAULT_URL,
    timeout: float = 60.0,
) -> bytes:
    """Get a PNG thumbnail of the template's bundled sample. Cached server-side
    on a content hash; ppi clamped to 36..300."""
    r = httpx.get(f"{url}/templates/{template}/preview.png", params={"ppi": ppi}, timeout=timeout)
    if r.status_code != 200:
        raise ConvertError(r.status_code, r.text)
    return r.content


def list_fonts(url: str = DEFAULT_URL, timeout: float = 10.0) -> list[str]:
    """Return font family names installed in the doc-forge container."""
    r = httpx.get(f"{url}/fonts", timeout=timeout)
    r.raise_for_status()
    return r.json().get("families", [])


def list_finalizers(url: str = DEFAULT_URL, timeout: float = 10.0) -> list[dict]:
    """Return the prepress finalizer registry (kdp-print-bw, web-pdf, etc.)."""
    r = httpx.get(f"{url}/finalizers", timeout=timeout)
    r.raise_for_status()
    return r.json().get("finalizers", [])


def list_augmenters(url: str = DEFAULT_URL, timeout: float = 10.0) -> list[dict]:
    """Return the AI-augmentation registry (summarize_md, etc.)."""
    r = httpx.get(f"{url}/augmenters", timeout=timeout)
    r.raise_for_status()
    return r.json().get("augmenters", [])


def render(
    template: str,
    data: dict,
    assets: Sequence = (),
    to: str = "pdf",
    determinize: bool = False,
    url: str = DEFAULT_URL,
    timeout: float = DEFAULT_TIMEOUT,
) -> bytes:
    """Render a registered template (book, flyer, resume, zine, business-card,
    poster) with caller-supplied data. See list_templates() for available ids
    and their schemas.
    """
    import json as _json
    files = [_to_multipart("assets", a) for a in assets]
    form_data = {"template": template, "data": _json.dumps(data), "to": to}
    if determinize:
        form_data["determinize"] = "true"
    r = httpx.post(f"{url}/render", files=files or None, data=form_data, timeout=timeout)
    if r.status_code != 200:
        raise ConvertError(r.status_code, r.text)
    return r.content


def finalize(
    pdf_bytes: bytes,
    target: str,
    filename: str = "input.pdf",
    url: str = DEFAULT_URL,
    timeout: float = DEFAULT_TIMEOUT,
) -> bytes:
    """Run a per-target prepress finalizer.

    target: kdp-print-bw, kdp-print-color, web-pdf (see list_finalizers).
    Strips dates, embeds fonts, downsamples images per target's needs.
    """
    files = {"file": (filename, pdf_bytes, "application/pdf")}
    r = httpx.post(f"{url}/finalize", files=files, data={"target": target}, timeout=timeout)
    if r.status_code != 200:
        raise ConvertError(r.status_code, r.text)
    return r.content


def impose(
    pdf_bytes: bytes,
    layout: str = "booklet",
    filename: str = "input.pdf",
    url: str = DEFAULT_URL,
    timeout: float = DEFAULT_TIMEOUT,
) -> bytes:
    """Impose a PDF for fold/cut printing. layout=booklet (saddle-stitch 2-up)."""
    files = {"file": (filename, pdf_bytes, "application/pdf")}
    r = httpx.post(f"{url}/impose", files=files, data={"layout": layout}, timeout=timeout)
    if r.status_code != 200:
        raise ConvertError(r.status_code, r.text)
    return r.content


def determinize(
    pdf_bytes: bytes,
    filename: str = "input.pdf",
    url: str = DEFAULT_URL,
    timeout: float = DEFAULT_TIMEOUT,
) -> bytes:
    """Strip nondeterministic metadata (CreationDate, ModDate, /ID) for
    byte-stable PDFs across hosts. Required when content-addressing renditions."""
    files = {"file": (filename, pdf_bytes, "application/pdf")}
    r = httpx.post(f"{url}/determinize", files=files, timeout=timeout)
    if r.status_code != 200:
        raise ConvertError(r.status_code, r.text)
    return r.content


def holon_render(
    template: str,
    data: dict,
    metadata: dict | None = None,
    assets: Sequence = (),
    to: str = "pdf",
    url: str = DEFAULT_URL,
    timeout: float = DEFAULT_TIMEOUT,
) -> tuple[str, bytes]:
    """Slice-1 holon render: content-addressed, cached.

    Returns (cid, bytes). Identical inputs always return the same CID; the
    second call with the same inputs returns from cache in <1s.
    """
    import json as _json
    files = [_to_multipart("assets", a) for a in assets]
    form_data = {
        "template": template,
        "data": _json.dumps(data),
        "metadata": _json.dumps(metadata or {}),
        "to": to,
    }
    r = httpx.post(f"{url}/holon/render", files=files or None, data=form_data, timeout=timeout)
    if r.status_code != 200:
        raise ConvertError(r.status_code, r.text)
    cid = r.headers.get("X-Doc-Forge-Holon-Cid", "")
    return cid, r.content


def holon_glue(
    children: list[str],
    metadata: dict | None = None,
    cover: bytes | None = None,
    back: bytes | None = None,
    to: str = "pdf",
    url: str = DEFAULT_URL,
    timeout: float = DEFAULT_TIMEOUT,
) -> tuple[str, bytes]:
    """Slice-2 holon glue: sequential concat of cached child PDFs.

    Children must already exist in the holon cache (rendered via holon_render
    or a prior holon_glue). Optional cover and back PDF bytes inline.
    Returns (cid, bytes).
    """
    import json as _json
    files: list = []
    if cover is not None:
        files.append(("cover", ("cover.pdf", cover, "application/pdf")))
    if back is not None:
        files.append(("back", ("back.pdf", back, "application/pdf")))
    form_data = {
        "children": _json.dumps(children),
        "metadata": _json.dumps(metadata or {}),
        "to": to,
    }
    r = httpx.post(f"{url}/holon/glue", files=files or None, data=form_data, timeout=timeout)
    if r.status_code != 200:
        raise ConvertError(r.status_code, r.text)
    cid = r.headers.get("X-Doc-Forge-Holon-Cid", "")
    return cid, r.content


def augment(
    md_bytes: bytes,
    op: str,
    model: str | None = None,
    filename: str = "doc.md",
    url: str = DEFAULT_URL,
    timeout: float = 120.0,
) -> bytes:
    """AI-augmented pass over a markdown document.

    op: summarize_md (TL;DR prepended), section_summaries_md (per-section).
    See list_augmenters() for available ops.
    """
    files = {"file": (filename, md_bytes, "text/markdown")}
    form_data = {"op": op}
    if model:
        form_data["model"] = model
    r = httpx.post(f"{url}/augment", files=files, data=form_data, timeout=timeout)
    if r.status_code != 200:
        raise ConvertError(r.status_code, r.text)
    return r.content


# ---------------------------------------------------------------------------
# CLI: subcommands. Backwards compat: when first arg is an existing file path
# (legacy `docforge_client.py SRC DST [...]` shape), fall through to convert.
# ---------------------------------------------------------------------------

def _add_url_arg(p):
    p.add_argument("--url", default=DEFAULT_URL, help=f"doc-forge base URL (default {DEFAULT_URL})")


def _cmd_convert(args) -> int:
    target = args.dst.suffix.lstrip(".").lower()
    if not target:
        print("error: destination must have an extension", file=sys.stderr)
        return 2
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


def _cmd_render(args) -> int:
    import json as _json
    data = _json.loads(args.data.read_text(encoding="utf-8"))
    out = render(
        template=args.template,
        data=data,
        assets=args.asset,
        to=args.dst.suffix.lstrip(".").lower() or "pdf",
        determinize=args.determinize,
        url=args.url,
    )
    args.dst.write_bytes(out)
    print(f"wrote {args.dst} ({len(out):,} bytes) — template={args.template}")
    return 0


def _cmd_finalize(args) -> int:
    raw = args.src.read_bytes()
    out = finalize(raw, target=args.target, filename=args.src.name, url=args.url)
    args.dst.write_bytes(out)
    print(f"wrote {args.dst} ({len(out):,} bytes) — target={args.target}")
    return 0


def _cmd_impose(args) -> int:
    raw = args.src.read_bytes()
    out = impose(raw, layout=args.layout, filename=args.src.name, url=args.url)
    args.dst.write_bytes(out)
    print(f"wrote {args.dst} ({len(out):,} bytes) — layout={args.layout}")
    return 0


def _cmd_determinize(args) -> int:
    raw = args.src.read_bytes()
    out = determinize(raw, filename=args.src.name, url=args.url)
    args.dst.write_bytes(out)
    print(f"wrote {args.dst} ({len(out):,} bytes)")
    return 0


def _cmd_augment(args) -> int:
    raw = args.src.read_bytes()
    out = augment(raw, op=args.op, model=args.model, filename=args.src.name, url=args.url)
    args.dst.write_bytes(out)
    print(f"wrote {args.dst} ({len(out):,} bytes) — op={args.op}")
    return 0


def _cmd_list(args) -> int:
    import json as _json
    if args.what == "templates":
        body = list_templates(url=args.url)
    elif args.what == "fonts":
        body = list_fonts(url=args.url)
        if args.filter:
            f = args.filter.lower()
            body = [n for n in body if f in n.lower()]
    elif args.what == "finalizers":
        body = list_finalizers(url=args.url)
    elif args.what == "augmenters":
        body = list_augmenters(url=args.url)
    elif args.what == "formats":
        body = formats(url=args.url)
    elif args.what == "health":
        body = health(url=args.url)
    else:
        print(f"unknown list target: {args.what}", file=sys.stderr)
        return 2
    print(_json.dumps(body, indent=2))
    return 0


def _main() -> int:
    import argparse
    import sys as _sys

    # Backwards compat: legacy `docforge_client.py SRC DST [...]` form. If the
    # first arg looks like a file path (exists or has a known extension), insert
    # `convert` as an explicit subcommand.
    argv = _sys.argv[1:]
    LEGACY_PASSTHROUGH = {"convert", "render", "finalize", "impose", "determinize",
                          "augment", "list", "-h", "--help"}
    if argv and argv[0] not in LEGACY_PASSTHROUGH and not argv[0].startswith("-"):
        argv = ["convert", *argv]

    ap = argparse.ArgumentParser(prog="docforge", description="doc-forge CLI")
    sub = ap.add_subparsers(dest="cmd", required=True)

    # convert
    p = sub.add_parser("convert", help="convert SRC to DST format (extension drives target)")
    p.add_argument("src", type=Path)
    p.add_argument("dst", type=Path)
    p.add_argument("--asset", type=Path, action="append", default=[],
                   help="sibling asset (repeatable)")
    p.add_argument("--engine", default=None,
                   help="force engine: libreoffice|tectonic|typst|pandoc|scribus|inkscape|graphviz|plantuml|mermaid|vips")
    _add_url_arg(p)
    p.set_defaults(func=_cmd_convert)

    # render
    p = sub.add_parser("render", help="render a registered template + JSON data → DST")
    p.add_argument("template", help="template id (book|flyer|resume|zine|business-card|poster)")
    p.add_argument("data", type=Path, help="JSON data file matching the template's schema")
    p.add_argument("dst", type=Path, help="output path (extension drives format: pdf|png|svg)")
    p.add_argument("--asset", type=Path, action="append", default=[],
                   help="sibling asset for the template (repeatable)")
    p.add_argument("--determinize", action="store_true",
                   help="strip nondeterministic PDF metadata for byte-stable output")
    _add_url_arg(p)
    p.set_defaults(func=_cmd_render)

    # finalize
    p = sub.add_parser("finalize", help="run a prepress finalizer on a PDF")
    p.add_argument("src", type=Path)
    p.add_argument("dst", type=Path)
    p.add_argument("target", help="kdp-print-bw|kdp-print-color|web-pdf")
    _add_url_arg(p)
    p.set_defaults(func=_cmd_finalize)

    # impose
    p = sub.add_parser("impose", help="impose a PDF for fold/cut printing")
    p.add_argument("src", type=Path)
    p.add_argument("dst", type=Path)
    p.add_argument("--layout", default="booklet",
                   help="booklet (saddle-stitch 2-up). zine-8up + signature-16 stubbed.")
    _add_url_arg(p)
    p.set_defaults(func=_cmd_impose)

    # determinize
    p = sub.add_parser("determinize", help="strip nondeterministic PDF metadata")
    p.add_argument("src", type=Path)
    p.add_argument("dst", type=Path)
    _add_url_arg(p)
    p.set_defaults(func=_cmd_determinize)

    # augment
    p = sub.add_parser("augment", help="run an AI augmentation pass over a markdown file")
    p.add_argument("src", type=Path)
    p.add_argument("dst", type=Path)
    p.add_argument("op", help="summarize_md|section_summaries_md")
    p.add_argument("--model", default=None, help="override default LiteLLM-routed model")
    _add_url_arg(p)
    p.set_defaults(func=_cmd_augment)

    # list
    p = sub.add_parser("list", help="list registry contents (templates, fonts, finalizers, …)")
    p.add_argument("what", choices=["templates", "fonts", "finalizers", "augmenters", "formats", "health"])
    p.add_argument("--filter", default=None, help="substring filter (fonts only)")
    _add_url_arg(p)
    p.set_defaults(func=_cmd_list)

    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(_main())
