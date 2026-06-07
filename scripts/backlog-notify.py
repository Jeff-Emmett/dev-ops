#!/usr/bin/env python3
"""
Backlog task completion email notifier.

Triggered by backlog-md's onStatusChange callback.
Sends an email when a task transitions to "Done" status,
extracting URLs and acceptance criteria from the task file.

Environment variables (set by backlog-md):
  TASK_ID     - e.g. "task-42"
  OLD_STATUS  - e.g. "In Progress"
  NEW_STATUS  - e.g. "Done"
  TASK_TITLE  - e.g. "Deploy new service"

SMTP credentials:
  ~/.secrets/private/claude_jeffemmett_password (file, preferred)
  $SMTP_PASS env var (fallback)
"""

import glob
import hashlib
import os
import re
import shutil
import smtplib
import subprocess
import sys
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path

# --- Configuration ---
SMTP_HOST = "mail.rmail.online"
SMTP_PORT = 587
SMTP_USER = "claude@jeffemmett.com"
SMTP_PASS_FILE = os.path.expanduser("~/.secrets/private/claude_jeffemmett_password")
FROM_ADDR = "Claude <claude@jeffemmett.com>"
TO_ADDR = "jeff@jeffemmett.com"

MEDIA_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".bmp", ".ico",
    ".pdf", ".mp4", ".webm", ".mov", ".avi", ".mp3", ".wav", ".ogg",
    ".zip", ".tar", ".gz", ".7z",
}


def get_smtp_password():
    """Read SMTP password from secret file or env var."""
    if os.path.isfile(SMTP_PASS_FILE):
        return Path(SMTP_PASS_FILE).read_text().strip()
    password = os.environ.get("SMTP_PASS")
    if password:
        return password
    print("ERROR: No SMTP password found", file=sys.stderr)
    sys.exit(1)


def find_task_file(task_id):
    """Locate the task markdown file, matching the ID EXACTLY.

    Task IDs come as TASK-123 from the callback but files are named
    `task-123 - <slug>.md`. A naive prefix glob (`task-396.1*`) collides for
    hierarchical IDs — it also matches `task-396.10`, `task-396.11`, …,
    `task-396.16` — and picking matches[0] reads the WRONG task's acceptance
    criteria (the bug that made the AC gate revert 396.1 based on 396.14's
    unchecked ACs). We disambiguate two ways, strongest first:

      1. the `id:` frontmatter field equals task_id (case-insensitive), or
      2. the filename's id segment (text between `task-` prefix and the
         ` - ` slug separator, or the `.md` end) equals the numeric id.
    """
    file_id = task_id.lower()                 # "task-396.1"
    numeric_id = file_id[len("task-"):]       # "396.1"
    candidates = glob.glob(f"backlog/tasks/{file_id}*")
    if not candidates:
        print(f"ERROR: No task file found for {task_id} (glob: backlog/tasks/{file_id}*)", file=sys.stderr)
        sys.exit(1)

    def id_segment(path):
        """The id portion of the filename, e.g. '396.1' from 'task-396.1 - x.md'."""
        name = os.path.basename(path)
        if name.lower().endswith(".md"):
            name = name[:-3]
        stem = name[len("task-"):] if name.lower().startswith("task-") else name
        # The slug (if any) is separated by " - "; the id is everything before it.
        return stem.split(" - ", 1)[0].strip().lower()

    # 1. Exact filename id-segment match (cheap, no file read).
    exact = [p for p in candidates if id_segment(p) == numeric_id]
    if len(exact) == 1:
        return exact[0]

    # 2. Tie-break / fallback on the `id:` frontmatter field.
    for path in (exact or candidates):
        try:
            head = Path(path).read_text()[:512]
            m = re.search(r'^id:\s*(\S+)\s*$', head, re.MULTILINE | re.IGNORECASE)
            if m and m.group(1).strip().lower() == file_id:
                return path
        except OSError:
            continue

    if exact:
        return exact[0]
    print(
        f"ERROR: Could not disambiguate task file for {task_id} among "
        f"{[os.path.basename(p) for p in candidates]}",
        file=sys.stderr,
    )
    sys.exit(1)


def get_project_name():
    """Read project name from backlog config (simple regex, no yaml dep)."""
    config_path = "backlog/config.yml"
    if os.path.isfile(config_path):
        content = Path(config_path).read_text()
        match = re.search(r'^project_name:\s*(.+)$', content, re.MULTILINE)
        if match:
            return match.group(1).strip().strip("'\"")
    return "Unknown Project"


def extract_urls(content):
    """Extract all URLs from markdown content, categorized."""
    url_pattern = re.compile(r'https?://[^\s\)\]>"\'`]+')
    urls = list(dict.fromkeys(url_pattern.findall(content)))  # dedupe, preserve order

    output_products = []
    links_to_test = []

    for url in urls:
        clean = url.rstrip(".,;:!?)")
        parsed_path = clean.split("?")[0].split("#")[0]
        ext = os.path.splitext(parsed_path)[1].lower()
        if ext in MEDIA_EXTENSIONS:
            output_products.append(clean)
        else:
            links_to_test.append(clean)

    return output_products, links_to_test


def extract_acceptance_criteria(content):
    """Extract acceptance criteria checkboxes."""
    ac_section = re.search(r'<!-- AC:BEGIN -->(.*?)<!-- AC:END -->', content, re.DOTALL)
    if not ac_section:
        return []

    criteria = []
    for line in ac_section.group(1).strip().splitlines():
        line = line.strip()
        if line.startswith("- [x]"):
            criteria.append((True, line[6:].strip()))
        elif line.startswith("- [ ]"):
            criteria.append((False, line[6:].strip()))

    return criteria


def build_html_email(task_id, title, project, output_products, links_to_test, criteria):
    """Build HTML email body."""
    html = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: -apple-system, system-ui, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; color: #333;">
<h2 style="border-bottom: 2px solid #22c55e; padding-bottom: 8px;">
  &#x2705; {task_id}: {title}
</h2>
<p style="color: #666; margin-top: -8px;">Project: <strong>{project}</strong></p>
"""

    if output_products:
        html += """<h3 style="color: #16a34a;">&#x1f4e6; Output Products</h3><ul>"""
        for url in output_products:
            html += f'<li><a href="{url}" style="color: #16a34a;">{url}</a></li>'
        html += "</ul>"

    if links_to_test:
        html += """<h3 style="color: #dc2626;">&#x1f517; Live URLs to Test</h3><ul>"""
        for url in links_to_test:
            html += f'<li><a href="{url}" style="color: #dc2626;">{url}</a></li>'
        html += "</ul>"
    else:
        html += """<p style="color: #b45309; background: #fef3c7; padding: 8px 12px; border-radius: 4px;">
&#x26a0;&#xfe0f; <strong>No live URLs found in task.</strong> Consider adding deployment links to the task notes.</p>"""

    if criteria:
        total = len(criteria)
        checked = sum(1 for c, _ in criteria if c)
        if checked < total:
            html += f"""<h3 style="color: #dc2626;">&#x274c; Acceptance Criteria ({checked}/{total}) — INCOMPLETE</h3>"""
        else:
            html += f"""<h3 style="color: #16a34a;">&#x2705; Acceptance Criteria ({checked}/{total})</h3>"""
        html += """<ul style="list-style: none; padding-left: 0;">"""
        for done, text in criteria:
            icon = "&#x2705;" if done else "&#x274c;"
            html += f"<li>{icon} {text}</li>"
        html += "</ul>"

    if not output_products and not links_to_test and not criteria:
        html += "<p><em>No URLs or acceptance criteria found in task.</em></p>"

    html += """<hr style="border: none; border-top: 1px solid #ddd; margin-top: 24px;">
<p style="color: #555; font-size: 13px;"><strong>Reply to this email</strong> with follow-up instructions, questions, or feedback. Your reply will be processed and a summary sent back.</p>
<p style="color: #999; font-size: 12px;">Claude &mdash; backlog-notify</p>
</body></html>"""

    return html


def build_text_email(task_id, title, project, output_products, links_to_test, criteria):
    """Build plaintext email body."""
    lines = [
        f"DONE: {task_id}: {title}",
        f"Project: {project}",
        "",
    ]

    if output_products:
        lines.append("OUTPUT PRODUCTS:")
        for url in output_products:
            lines.append(f"  - {url}")
        lines.append("")

    if links_to_test:
        lines.append("LIVE URLs TO TEST:")
        for url in links_to_test:
            lines.append(f"  - {url}")
        lines.append("")
    else:
        lines.append("WARNING: No live URLs found in task. Add deployment links to task notes.")
        lines.append("")

    if criteria:
        total = len(criteria)
        checked = sum(1 for c, _ in criteria if c)
        status = " — INCOMPLETE" if checked < total else ""
        lines.append(f"ACCEPTANCE CRITERIA ({checked}/{total}){status}:")
        for done, text in criteria:
            mark = "[x]" if done else "[ ]"
            lines.append(f"  {mark} {text}")
        lines.append("")

    if not output_products and not links_to_test and not criteria:
        lines.append("No URLs or acceptance criteria found in task.")

    lines.append("")
    lines.append("---")
    lines.append("Reply to this email with follow-up instructions or feedback.")
    lines.append("Your reply will be processed and a summary sent back.")
    lines.append("")
    lines.append("-- Claude (backlog-notify)")
    return "\n".join(lines)


def send_email(subject, html_body, text_body, message_id=None):
    """Send multipart email via Mailcow SMTP."""
    password = get_smtp_password()

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = FROM_ADDR
    msg["To"] = TO_ADDR
    msg["Reply-To"] = "claude@jeffemmett.com"
    if message_id:
        msg["Message-ID"] = message_id

    msg.attach(MIMEText(text_body, "plain"))
    msg.attach(MIMEText(html_body, "html"))

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
        server.starttls()
        server.login(SMTP_USER, password)
        server.sendmail(SMTP_USER, [TO_ADDR], msg.as_string())

    print(f"Email sent: {subject}")


def revert_task_status(task_id, old_status, reason):
    """Revert task status and append a note explaining why."""
    backlog_cmd = shutil.which("backlog") or "backlog"
    note = f"[AC GATE] Reverted to '{old_status}': {reason}"
    try:
        subprocess.run(
            [backlog_cmd, "task", "edit", task_id, "-s", old_status,
             "--append-notes", note],
            check=True, capture_output=True, text=True, timeout=30,
        )
        print(f"Reverted {task_id} to '{old_status}': {reason}")
    except Exception as e:
        print(f"ERROR: Failed to revert {task_id}: {e}", file=sys.stderr)


def send_rejection_email(task_id, task_title, project, criteria, checked_ac, total_ac):
    """Send email notifying that task completion was rejected due to unchecked ACs."""
    unchecked = [(i + 1, text) for i, (done, text) in enumerate(criteria) if not done]

    subject = f"[REJECTED] {task_id}: {task_title} — {total_ac - checked_ac} ACs incomplete"
    msg_hash = hashlib.sha256(f"{task_id}-{project}".encode()).hexdigest()[:12]
    message_id = f"<backlog-reject-{task_id.lower()}-{msg_hash}@jeffemmett.com>"

    ac_list_html = "".join(
        f'<li style="color: #dc2626;">&#x274c; AC #{idx}: {text}</li>'
        for idx, text in unchecked
    )
    html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="font-family: -apple-system, system-ui, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; color: #333;">
<h2 style="border-bottom: 2px solid #dc2626; padding-bottom: 8px; color: #dc2626;">
  &#x1f6d1; {task_id}: {task_title}
</h2>
<p style="color: #666;">Project: <strong>{project}</strong></p>
<p>Task was marked Done but <strong>{total_ac - checked_ac} of {total_ac} acceptance criteria</strong> are still unchecked. Status has been reverted to <strong>In Progress</strong>.</p>
<h3>Unchecked Acceptance Criteria:</h3>
<ul style="list-style: none; padding-left: 0;">{ac_list_html}</ul>
<p style="background: #fef3c7; padding: 10px; border-radius: 4px;">
To complete this task, check all ACs with <code>backlog task edit {task_id} --check-ac N</code> then set status to Done.<br>
To override, add <code>&lt;!-- AC_WAIVED --&gt;</code> to the task file.</p>
<hr style="border: none; border-top: 1px solid #ddd; margin-top: 24px;">
<p style="color: #555; font-size: 13px;"><strong>Reply</strong> to provide instructions or override.</p>
<p style="color: #999; font-size: 12px;">Claude &mdash; backlog-notify (AC gate)</p>
</body></html>"""

    text = f"""REJECTED: {task_id}: {task_title}
Project: {project}

Task was marked Done but {total_ac - checked_ac}/{total_ac} acceptance criteria are unchecked.
Status reverted to In Progress.

UNCHECKED ACs:
""" + "\n".join(f"  [ ] AC #{idx}: {text}" for idx, text in unchecked) + f"""

To complete: check all ACs with `backlog task edit {task_id} --check-ac N` then set status to Done.
To override: add <!-- AC_WAIVED --> to the task file.

---
Reply to provide instructions or override.
-- Claude (backlog-notify, AC gate)"""

    send_email(subject, html, text, message_id=message_id)


def main():
    # Read env vars from backlog-md callback
    task_id = os.environ.get("TASK_ID", "")
    old_status = os.environ.get("OLD_STATUS", "")
    new_status = os.environ.get("NEW_STATUS", "")
    task_title = os.environ.get("TASK_TITLE", "")

    # Only act on transitions to Done
    if new_status != "Done":
        sys.exit(0)

    if not task_id:
        print("ERROR: TASK_ID not set", file=sys.stderr)
        sys.exit(1)

    # Find and read task file
    task_file = find_task_file(task_id)
    content = Path(task_file).read_text()

    # Extract data
    project = get_project_name()
    output_products, links_to_test = extract_urls(content)
    criteria = extract_acceptance_criteria(content)

    # --- AC Gate: reject completion if ACs are incomplete ---
    total_ac = len(criteria)
    checked_ac = sum(1 for done, _ in criteria if done)
    ac_incomplete = total_ac > 0 and checked_ac < total_ac
    ac_waived = "<!-- AC_WAIVED -->" in content

    if ac_incomplete and not ac_waived:
        print(f"AC GATE: {task_id} has {total_ac - checked_ac}/{total_ac} unchecked ACs — reverting")
        revert_task_status(task_id, old_status or "In Progress",
                          f"{total_ac - checked_ac}/{total_ac} ACs unchecked")
        send_rejection_email(task_id, task_title, project, criteria, checked_ac, total_ac)
        sys.exit(0)

    # --- All ACs passed (or no ACs / waived) — send completion email ---
    subject = f"[DONE] {task_id}: {task_title}"

    # Generate stable Message-ID for reply threading
    msg_hash = hashlib.sha256(f"{task_id}-{project}".encode()).hexdigest()[:12]
    message_id = f"<backlog-{task_id.lower()}-{msg_hash}@jeffemmett.com>"

    html_body = build_html_email(task_id, task_title, project, output_products, links_to_test, criteria)
    text_body = build_text_email(task_id, task_title, project, output_products, links_to_test, criteria)
    send_email(subject, html_body, text_body, message_id=message_id)


if __name__ == "__main__":
    main()
