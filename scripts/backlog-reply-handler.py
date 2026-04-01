#!/usr/bin/env python3
"""
Backlog Reply Handler — polls IMAP for replies to backlog notification emails,
processes them as Claude prompts with task context, and emails results back.

Designed to run as a long-lived process (e.g., systemd service or Docker container).

Watches claude@jeffemmett.com for replies to [DONE] backlog emails.
When a reply is found:
  1. Extracts the reply text (strips quoted content)
  2. Loads the referenced task file for context
  3. Runs Claude CLI with the reply as a prompt
  4. Emails the result to jeff@jeffemmett.com as a threaded reply

Environment variables:
  IMAP_HOST     - IMAP server (default: mail.rmail.online)
  IMAP_PORT     - IMAP port (default: 993)
  IMAP_USER     - IMAP username (default: claude@jeffemmett.com)
  IMAP_PASS     - IMAP password (or read from SMTP_PASS_FILE)
  SMTP_HOST     - SMTP server (default: mail.rmail.online)
  SMTP_PORT     - SMTP port (default: 587)
  SMTP_USER     - SMTP username (default: claude@jeffemmett.com)
  SMTP_PASS     - SMTP password (or read from SMTP_PASS_FILE)
  SMTP_PASS_FILE - Path to password file (default: ~/.secrets/private/claude_jeffemmett_password)
  REPLY_TO      - Where to send results (default: jeff@jeffemmett.com)
  BACKLOG_ROOT  - Path to backlog tasks (default: auto-detect from git root)
  POLL_INTERVAL - Seconds between IMAP checks (default: 120)
  CLAUDE_CMD    - Claude CLI command (default: claude)
  MAX_BUDGET    - Max budget per reply (default: 1.00)
  ALLOWED_SENDERS - Comma-separated allowed sender addresses
"""

import email
import email.utils
import imaplib
import json
import logging
import os
import re
import smtplib
import subprocess
import sys
import time
from datetime import datetime, timedelta
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("backlog-reply-handler")

# ─── Configuration ────────────────────────────────────────────────────

IMAP_HOST = os.environ.get("IMAP_HOST", "mail.rmail.online")
IMAP_PORT = int(os.environ.get("IMAP_PORT", "993"))
IMAP_USER = os.environ.get("IMAP_USER", "claude@jeffemmett.com")

SMTP_HOST = os.environ.get("SMTP_HOST", "mail.rmail.online")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "claude@jeffemmett.com")

SMTP_PASS_FILE = os.path.expanduser(
    os.environ.get("SMTP_PASS_FILE", "~/.secrets/private/claude_jeffemmett_password")
)
REPLY_TO = os.environ.get("REPLY_TO", "jeff@jeffemmett.com")
POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", "120"))
MAX_BUDGET = os.environ.get("MAX_BUDGET", "1.00")

CLAUDE_CMD = os.environ.get("CLAUDE_CMD", "claude")

ALLOWED_SENDERS = [
    s.strip().lower()
    for s in os.environ.get("ALLOWED_SENDERS", "jeff@jeffemmett.com").split(",")
    if s.strip()
]

# Track processed message IDs to avoid re-processing
STATE_FILE = Path(os.environ.get("STATE_FILE", "/tmp/backlog-reply-state.json"))


def get_password():
    """Read password from file or env var."""
    env_pass = os.environ.get("SMTP_PASS") or os.environ.get("IMAP_PASS")
    if env_pass:
        return env_pass
    if os.path.isfile(SMTP_PASS_FILE):
        return Path(SMTP_PASS_FILE).read_text().strip()
    log.error("No password found (set SMTP_PASS or create %s)", SMTP_PASS_FILE)
    sys.exit(1)


def load_state() -> set:
    """Load set of processed message IDs."""
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text())
            return set(data.get("processed", []))
        except (json.JSONDecodeError, KeyError):
            pass
    return set()


def save_state(processed: set):
    """Save processed message IDs (keep last 500)."""
    ids = sorted(processed)[-500:]
    STATE_FILE.write_text(json.dumps({"processed": ids}))


def find_backlog_root() -> Path:
    """Find the backlog tasks directory."""
    env = os.environ.get("BACKLOG_ROOT")
    if env:
        return Path(env)
    # Try git root
    try:
        root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        candidate = Path(root) / "backlog" / "tasks"
        if candidate.is_dir():
            return candidate
    except Exception:
        pass
    # Scan common locations
    for base in [Path.home() / "Github"]:
        for config in base.glob("*/backlog/config.yml"):
            tasks_dir = config.parent / "tasks"
            if tasks_dir.is_dir():
                return tasks_dir
    return Path("backlog/tasks")


def find_task_file(task_id: str, backlog_root: Path) -> Path | None:
    """Find task file by ID across all backlog directories."""
    file_id = task_id.lower()
    # Search provided root
    matches = list(backlog_root.glob(f"{file_id}*"))
    if matches:
        return matches[0]
    # Search all project backlogs
    for tasks_dir in (Path.home() / "Github").glob("*/backlog/tasks"):
        matches = list(tasks_dir.glob(f"{file_id}*"))
        if matches:
            return matches[0]
    return None


def extract_task_id_from_subject(subject: str) -> str | None:
    """Extract task ID from email subject like '[DONE] TASK-42: ...'."""
    match = re.search(r'(task-\d+)', subject, re.IGNORECASE)
    return match.group(1) if match else None


def extract_plain_text(msg: email.message.Message) -> str:
    """Extract plaintext body from email message."""
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                payload = part.get_payload(decode=True)
                if payload:
                    return payload.decode(
                        part.get_content_charset() or "utf-8", errors="replace"
                    )
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            return payload.decode(
                msg.get_content_charset() or "utf-8", errors="replace"
            )
    return ""


def strip_quoted_content(body: str) -> str:
    """Remove quoted reply content (lines starting with >) and email signatures."""
    lines = body.split("\n")
    result = []
    for line in lines:
        stripped = line.strip()
        # Stop at quoted content or common separators
        if stripped.startswith(">"):
            continue
        if stripped.startswith("On ") and stripped.endswith("wrote:"):
            break
        if stripped == "-- " or stripped == "--":
            break
        if "Original Message" in stripped:
            break
        if "backlog-notify" in stripped.lower():
            break
        result.append(line)
    return "\n".join(result).strip()


def run_claude(prompt: str, task_context: str) -> str:
    """Run Claude CLI with task context and user prompt."""
    full_prompt = f"""You received a reply to a backlog task completion email.

TASK CONTEXT:
{task_context[:3000]}

USER'S REPLY:
{prompt}

Respond helpfully. If they ask to check something, investigate. If they provide feedback, acknowledge and suggest next steps. If they ask for changes, describe what needs to happen.
Keep your response concise and actionable."""

    cmd = [
        CLAUDE_CMD, "-p", full_prompt,
        "--output-format", "text",
        "--max-budget-usd", MAX_BUDGET,
    ]

    log.info("Running Claude CLI (budget=$%s)", MAX_BUDGET)
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=300,
        )
        if result.returncode != 0:
            log.error("Claude error (rc=%d): %s", result.returncode, result.stderr[:500])
            return f"[Claude error: exit {result.returncode}]\n{result.stderr[:300]}"
        return result.stdout.strip() or "[Empty response]"
    except subprocess.TimeoutExpired:
        return "[Claude timed out after 300s]"
    except FileNotFoundError:
        return f"[Claude CLI not found at: {CLAUDE_CMD}]"
    except Exception as e:
        return f"[Error running Claude: {e}]"


def send_reply_email(
    to: str, subject: str, body: str,
    in_reply_to: str | None = None, references: str | None = None,
):
    """Send reply email via SMTP."""
    password = get_password()

    msg = MIMEMultipart("alternative")
    msg["From"] = "Claude <claude@jeffemmett.com>"
    msg["To"] = to
    msg["Subject"] = subject
    msg["Reply-To"] = "claude@jeffemmett.com"
    if in_reply_to:
        msg["In-Reply-To"] = in_reply_to
    if references:
        msg["References"] = references

    # Plaintext
    text = f"""{body}

---
Reply again to continue this thread.
-- Claude (backlog-reply-handler)"""
    msg.attach(MIMEText(text, "plain"))

    # HTML
    html = f"""<!DOCTYPE html>
<html><body style="font-family: -apple-system, system-ui, sans-serif; max-width: 600px; padding: 20px; color: #333;">
<div style="white-space: pre-wrap;">{body}</div>
<hr style="border: none; border-top: 1px solid #ddd; margin-top: 24px;">
<p style="color: #555; font-size: 13px;"><strong>Reply again</strong> to continue this thread.</p>
<p style="color: #999; font-size: 12px;">Claude &mdash; backlog-reply-handler</p>
</body></html>"""
    msg.attach(MIMEText(html, "html"))

    try:
        server = smtplib.SMTP(SMTP_HOST, SMTP_PORT)
        server.starttls()
        server.login(SMTP_USER, password)
        server.sendmail(SMTP_USER, [to], msg.as_string())
        server.quit()
        log.info("Reply sent to %s: %s", to, subject)
    except Exception as e:
        log.error("SMTP error: %s", e)


def check_for_replies(processed: set, backlog_root: Path) -> set:
    """Poll IMAP for new replies to backlog notification emails."""
    password = get_password()

    try:
        mail = imaplib.IMAP4_SSL(IMAP_HOST, IMAP_PORT)
        mail.login(IMAP_USER, password)
        mail.select("INBOX")

        # Search for recent emails with backlog subjects
        since = (datetime.now() - timedelta(days=7)).strftime("%d-%b-%Y")

        for sender in ALLOWED_SENDERS:
            # Search for replies to [DONE] emails
            status, data = mail.search(
                None, f'(FROM "{sender}" SUBJECT "[DONE]" SINCE {since})'
            )
            if status != "OK" or not data[0]:
                continue

            for msg_num in data[0].split():
                status, msg_data = mail.fetch(msg_num, "(BODY.PEEK[])")
                if status != "OK":
                    continue

                msg = email.message_from_bytes(msg_data[0][1])
                message_id = msg.get("Message-ID", "")

                if message_id in processed:
                    continue

                # Must be a reply (has In-Reply-To or References with our Message-ID pattern)
                in_reply_to = msg.get("In-Reply-To", "")
                references = msg.get("References", "")
                if not (
                    "backlog-task-" in in_reply_to
                    or "backlog-task-" in references
                    or in_reply_to  # any reply to a [DONE] email
                ):
                    continue

                subject = str(msg.get("Subject", ""))
                task_id = extract_task_id_from_subject(subject)
                body = extract_plain_text(msg)
                reply_text = strip_quoted_content(body)

                if not reply_text.strip():
                    processed.add(message_id)
                    continue

                log.info(
                    "Processing reply from %s for %s: %s",
                    sender, task_id or "unknown", reply_text[:80],
                )

                # Load task context
                task_context = ""
                if task_id:
                    task_file = find_task_file(task_id, backlog_root)
                    if task_file:
                        task_context = task_file.read_text()[:4000]
                        log.info("Loaded task context from %s", task_file)

                # Run Claude
                response = run_claude(reply_text, task_context)

                # Send result back
                reply_subject = f"Re: {subject}" if not subject.startswith("Re:") else subject
                send_reply_email(
                    to=REPLY_TO,
                    subject=reply_subject,
                    body=response,
                    in_reply_to=message_id,
                    references=f"{in_reply_to} {message_id}".strip(),
                )

                processed.add(message_id)

        mail.logout()
    except Exception as e:
        log.error("IMAP error: %s", e)

    return processed


def main():
    """Main polling loop."""
    backlog_root = find_backlog_root()
    log.info("Backlog root: %s", backlog_root)
    log.info("Polling %s every %ds for replies from %s",
             IMAP_USER, POLL_INTERVAL, ALLOWED_SENDERS)

    processed = load_state()
    log.info("Loaded %d previously processed message IDs", len(processed))

    while True:
        try:
            processed = check_for_replies(processed, backlog_root)
            save_state(processed)
        except Exception as e:
            log.error("Poll cycle error: %s", e)

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
