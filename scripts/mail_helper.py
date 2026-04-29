#!/usr/bin/env python3
"""Send mail (optionally with attachments) via the mailcow postfix container.

Generalizes the one-off `send_cynthia_email.py` pattern into a reusable
helper. Composes a MIMEMultipart message and pipes it to `sendmail` inside
the mailcow postfix container.

Designed to run on the netcup host where the mailcow stack lives. From
elsewhere, call this script over SSH or use the Mailcow MCP server.

Usage as a library:

    from mail_helper import send_mail

    send_mail(
        to="jeffemmett@gmail.com",
        subject="Weekly digest",
        body="Plain-text body here…",
        attachments=[Path("/tmp/digest.pdf"), ("inline.docx", b"...")],
    )

Usage as a CLI (for ad-hoc/automation):

    python3 mail_helper.py \\
        --to jeffemmett@gmail.com \\
        --subject "Weekly digest" \\
        --body-file /tmp/body.txt \\
        --attach /tmp/digest.pdf \\
        --attach /tmp/audit.pdf
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path
from typing import Iterable

DEFAULT_FROM = os.environ.get("MAIL_FROM", "claude@jeffemmett.com")
DEFAULT_FROM_NAME = os.environ.get("MAIL_FROM_NAME", "Claude")
POSTFIX_CONTAINER = os.environ.get(
    "POSTFIX_CONTAINER", "mailcowdockerized-postfix-mailcow-1"
)


class MailError(RuntimeError):
    """Raised when sendmail returns non-zero or times out."""


def _attachment_part(item) -> MIMEApplication:
    """Normalize Path or (name, bytes) into a MIMEApplication part."""
    if isinstance(item, Path):
        name = item.name
        data = item.read_bytes()
    else:
        name, data = item
    part = MIMEApplication(data, Name=name)
    part["Content-Disposition"] = f'attachment; filename="{name}"'
    return part


def send_mail(
    to: str,
    subject: str,
    body: str,
    attachments: Iterable = (),
    *,
    cc: str | None = None,
    bcc: str | None = None,
    sender: str = DEFAULT_FROM,
    sender_name: str = DEFAULT_FROM_NAME,
    in_reply_to: str | None = None,
    references: str | None = None,
    timeout: int = 60,
) -> str | None:
    """Build a MIMEMultipart message and send via mailcow postfix sendmail.

    Returns the Message-ID on success; raises MailError on failure.
    """
    msg = MIMEMultipart()
    msg["From"] = f"{sender_name} <{sender}>" if sender_name else sender
    msg["To"] = to
    msg["Subject"] = subject
    if cc:
        msg["Cc"] = cc
    if in_reply_to:
        msg["In-Reply-To"] = in_reply_to
    if references:
        msg["References"] = references

    msg.attach(MIMEText(body, "plain", "utf-8"))
    for a in attachments:
        msg.attach(_attachment_part(a))

    recipients = [to]
    if cc:
        recipients.append(cc)
    if bcc:
        recipients.append(bcc)

    raw = msg.as_string().encode("utf-8")
    cmd = [
        "docker", "exec", "-i", POSTFIX_CONTAINER,
        "sendmail", "-f", sender, *recipients,
    ]
    try:
        result = subprocess.run(cmd, input=raw, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired as e:
        raise MailError(f"sendmail timed out after {timeout}s") from e

    if result.returncode != 0:
        stderr = result.stderr.decode(errors="replace")[:1000]
        raise MailError(f"sendmail rc={result.returncode}: {stderr}")
    return msg.get("Message-ID")


def _main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--to", required=True)
    ap.add_argument("--subject", required=True)
    body_grp = ap.add_mutually_exclusive_group(required=True)
    body_grp.add_argument("--body", help="literal body text")
    body_grp.add_argument("--body-file", type=Path, help="read body from file")
    ap.add_argument("--attach", type=Path, action="append", default=[],
                    help="attach a file (repeatable)")
    ap.add_argument("--cc", default=None)
    ap.add_argument("--bcc", default=None)
    ap.add_argument("--from", dest="from_addr", default=DEFAULT_FROM)
    ap.add_argument("--from-name", default=DEFAULT_FROM_NAME)
    args = ap.parse_args()

    body = args.body if args.body is not None else args.body_file.read_text(encoding="utf-8")
    try:
        msg_id = send_mail(
            to=args.to,
            subject=args.subject,
            body=body,
            attachments=args.attach,
            cc=args.cc,
            bcc=args.bcc,
            sender=args.from_addr,
            sender_name=args.from_name,
        )
    except MailError as e:
        print(f"send failed: {e}", file=sys.stderr)
        return 1
    print(f"sent ({len(args.attach)} attachments)  Message-ID: {msg_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
