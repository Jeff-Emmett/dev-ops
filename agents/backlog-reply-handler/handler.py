#!/usr/bin/env python3
"""
Backlog Reply Handler — polls IMAP for replies to backlog notification emails,
processes them as Claude prompts with task context, and emails results back.

Runs as a Docker container on Netcup alongside Mailcow.

Watches claude@jeffemmett.com for replies to [DONE] or [REJECTED] emails.
When a reply is found:
  1. Extracts the reply text (strips quoted content)
  2. Loads the referenced task file for context (via docker exec into claude-dev)
  3. Runs Claude CLI with the reply as a prompt (via docker exec into claude-dev)
  4. Emails the result to jeff@jeffemmett.com as a threaded reply
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
from datetime import datetime, timedelta, timezone
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("/data/handler.log"),
    ],
)
log = logging.getLogger("backlog-reply-handler")

# ─── Configuration ────────────────────────────────────────────────────

IMAP_HOST = os.environ.get("IMAP_HOST", "mail.rmail.online")
IMAP_PORT = int(os.environ.get("IMAP_PORT", "993"))
IMAP_USER = os.environ.get("IMAP_USER", "claude@jeffemmett.com")
IMAP_PASS = os.environ.get("IMAP_PASS", "")

SMTP_HOST = os.environ.get("SMTP_HOST", "mail.rmail.online")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "claude@jeffemmett.com")
SMTP_PASS = os.environ.get("SMTP_PASS", "")

REPLY_TO_ADDR = os.environ.get("REPLY_TO", "jeff@jeffemmett.com")
POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", "120"))
MAX_BUDGET = os.environ.get("MAX_BUDGET", "1.00")

CLAUDE_CONTAINER = os.environ.get("CLAUDE_CONTAINER", "claude-dev")
CLAUDE_WORKDIR = os.environ.get("CLAUDE_WORKDIR", "/opt/apps")

ALLOWED_SENDERS = [
    s.strip().lower()
    for s in os.environ.get("ALLOWED_SENDERS", "jeff@jeffemmett.com").split(",")
    if s.strip()
]

STATE_FILE = Path("/data/state.json")


# ─── State Persistence ────────────────────────────────────────────────

def load_state() -> set:
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text())
            return set(data.get("processed", []))
        except (json.JSONDecodeError, KeyError):
            pass
    return set()


def save_state(processed: set):
    ids = sorted(processed)[-500:]
    STATE_FILE.write_text(json.dumps({"processed": ids, "updated": datetime.now(timezone.utc).isoformat()}))


# ─── Email Helpers ────────────────────────────────────────────────────

def extract_plain_text(msg: email.message.Message) -> str:
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                payload = part.get_payload(decode=True)
                if payload:
                    return payload.decode(part.get_content_charset() or "utf-8", errors="replace")
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            return payload.decode(msg.get_content_charset() or "utf-8", errors="replace")
    return ""


def strip_quoted_content(body: str) -> str:
    """Remove quoted reply content and signatures."""
    lines = body.split("\n")
    result = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith(">"):
            continue
        if stripped.startswith("On ") and stripped.endswith("wrote:"):
            break
        if stripped in ("-- ", "--"):
            break
        if "Original Message" in stripped:
            break
        if "backlog-notify" in stripped.lower() or "backlog-reply-handler" in stripped.lower():
            break
        result.append(line)
    return "\n".join(result).strip()


def extract_task_id_from_subject(subject: str) -> str | None:
    match = re.search(r'(task-\d+)', subject, re.IGNORECASE)
    return match.group(1) if match else None


# ─── Claude CLI via Docker Exec ───────────────────────────────────────

def read_task_file(task_id: str) -> str:
    """Read task file content via docker exec into claude-dev."""
    file_id = task_id.lower()
    # Find task file
    cmd = [
        "docker", "exec", CLAUDE_CONTAINER,
        "sh", "-c", f"cat $(ls {CLAUDE_WORKDIR}/*/backlog/tasks/{file_id}* 2>/dev/null | head -1) 2>/dev/null"
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception as e:
        log.warning("Could not read task file for %s: %s", task_id, e)
    return ""


def run_claude(prompt: str, task_context: str) -> str:
    """Run Claude CLI via docker exec into claude-dev."""
    full_prompt = f"""You received a reply to a backlog task notification email. The user is replying with follow-up instructions or feedback.

TASK CONTEXT:
{task_context[:3000]}

USER'S REPLY:
{prompt}

Respond helpfully and concisely. If they ask to check something, investigate. If they provide feedback, acknowledge and suggest next steps. If they ask for changes, describe what needs to happen or execute the changes if possible."""

    cmd = [
        "docker", "exec", "-w", CLAUDE_WORKDIR, CLAUDE_CONTAINER,
        "claude", "-p", full_prompt,
        "--output-format", "text",
        "--max-budget-usd", MAX_BUDGET,
    ]

    log.info("Running Claude CLI (budget=$%s)", MAX_BUDGET)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        if result.returncode != 0:
            log.error("Claude error (rc=%d): %s", result.returncode, result.stderr[:500])
            return f"[Claude error: exit {result.returncode}]\n{result.stderr[:300]}"
        return result.stdout.strip() or "[Empty response]"
    except subprocess.TimeoutExpired:
        return "[Claude timed out after 300s]"
    except Exception as e:
        return f"[Error running Claude: {e}]"


# ─── Send Reply Email ─────────────────────────────────────────────────

def send_reply_email(to, subject, body, in_reply_to=None, references=None):
    msg = MIMEMultipart("alternative")
    msg["From"] = "Claude <claude@jeffemmett.com>"
    msg["To"] = to
    msg["Subject"] = subject
    msg["Reply-To"] = "claude@jeffemmett.com"
    if in_reply_to:
        msg["In-Reply-To"] = in_reply_to
    if references:
        msg["References"] = references

    text = f"""{body}

---
Reply again to continue this thread.
-- Claude (backlog-reply-handler)"""
    msg.attach(MIMEText(text, "plain"))

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
        server.login(SMTP_USER, SMTP_PASS)
        server.sendmail(SMTP_USER, [to], msg.as_string())
        server.quit()
        log.info("Reply sent to %s: %s", to, subject)
    except Exception as e:
        log.error("SMTP error: %s", e)


# ─── IMAP Polling ─────────────────────────────────────────────────────

def check_for_replies(processed: set) -> set:
    try:
        mail = imaplib.IMAP4_SSL(IMAP_HOST, IMAP_PORT)
        mail.login(IMAP_USER, IMAP_PASS)
        mail.select("INBOX")

        since = (datetime.now() - timedelta(days=7)).strftime("%d-%b-%Y")

        for sender in ALLOWED_SENDERS:
            # Search for replies containing task IDs in subject
            for keyword in ["[DONE]", "[REJECTED]"]:
                status, data = mail.search(
                    None, f'(FROM "{sender}" SUBJECT "{keyword}" SINCE {since})'
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

                    # Must be a reply (has In-Reply-To header)
                    in_reply_to = msg.get("In-Reply-To", "")
                    references = msg.get("References", "")
                    if not in_reply_to:
                        # Not a reply — it's an original notification, skip
                        processed.add(message_id)
                        continue

                    subject = str(msg.get("Subject", ""))
                    task_id = extract_task_id_from_subject(subject)
                    body = extract_plain_text(msg)
                    reply_text = strip_quoted_content(body)

                    if not reply_text.strip():
                        processed.add(message_id)
                        continue

                    log.info("Processing reply from %s for %s: %.80s",
                             sender, task_id or "unknown", reply_text)

                    # Load task context
                    task_context = ""
                    if task_id:
                        task_context = read_task_file(task_id)
                        if task_context:
                            log.info("Loaded task context for %s (%d chars)", task_id, len(task_context))

                    # Run Claude
                    response = run_claude(reply_text, task_context)

                    # Send result back
                    reply_subject = f"Re: {subject}" if not subject.startswith("Re:") else subject
                    send_reply_email(
                        to=REPLY_TO_ADDR,
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


# ─── Main Loop ────────────────────────────────────────────────────────

def main():
    log.info("Backlog Reply Handler starting")
    log.info("Polling %s every %ds for replies from %s", IMAP_USER, POLL_INTERVAL, ALLOWED_SENDERS)

    processed = load_state()
    log.info("Loaded %d previously processed message IDs", len(processed))

    while True:
        try:
            processed = check_for_replies(processed)
            save_state(processed)
        except Exception as e:
            log.error("Poll cycle error: %s", e)
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
