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
  ~/.secrets/private/rmail_noreply_password (file, preferred)
  $SMTP_PASS env var (fallback)
"""

import glob
import os
import re
import smtplib
import sys
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path

# --- Configuration ---
SMTP_HOST = "mail.rmail.online"
SMTP_PORT = 587
SMTP_USER = "team@rmail.online"
SMTP_PASS_FILE = os.path.expanduser("~/.secrets/private/rmail_team_password")
FROM_ADDR = "Backlog Notify <team@rmail.online>"
TO_ADDR = "jeff+testing@jeffemmett.com"

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
    """Locate the task markdown file via glob."""
    # Task IDs come as TASK-123 from callback but files are task-123
    file_id = task_id.lower()
    matches = glob.glob(f"backlog/tasks/{file_id}*")
    if not matches:
        print(f"ERROR: No task file found for {task_id} (glob: backlog/tasks/{file_id}*)", file=sys.stderr)
        sys.exit(1)
    return matches[0]


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
        html += """<h3 style="color: #dc2626;">&#x1f517; Links to Test</h3><ul>"""
        for url in links_to_test:
            html += f'<li><a href="{url}" style="color: #dc2626;">{url}</a></li>'
        html += "</ul>"

    if criteria:
        total = len(criteria)
        checked = sum(1 for c, _ in criteria if c)
        html += f"""<h3>&#x2611;&#xfe0f; Acceptance Criteria ({checked}/{total})</h3><ul style="list-style: none; padding-left: 0;">"""
        for done, text in criteria:
            icon = "&#x2705;" if done else "&#x274c;"
            html += f"<li>{icon} {text}</li>"
        html += "</ul>"

    if not output_products and not links_to_test and not criteria:
        html += "<p><em>No URLs or acceptance criteria found in task.</em></p>"

    html += """<hr style="border: none; border-top: 1px solid #ddd; margin-top: 24px;">
<p style="color: #999; font-size: 12px;">Sent by backlog-notify</p>
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
        lines.append("LINKS TO TEST:")
        for url in links_to_test:
            lines.append(f"  - {url}")
        lines.append("")

    if criteria:
        total = len(criteria)
        checked = sum(1 for c, _ in criteria if c)
        lines.append(f"ACCEPTANCE CRITERIA ({checked}/{total}):")
        for done, text in criteria:
            mark = "[x]" if done else "[ ]"
            lines.append(f"  {mark} {text}")
        lines.append("")

    if not output_products and not links_to_test and not criteria:
        lines.append("No URLs or acceptance criteria found in task.")

    lines.append("---")
    lines.append("Sent by backlog-notify")
    return "\n".join(lines)


def send_email(subject, html_body, text_body):
    """Send multipart email via Mailcow SMTP."""
    password = get_smtp_password()

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = FROM_ADDR
    msg["To"] = TO_ADDR

    msg.attach(MIMEText(text_body, "plain"))
    msg.attach(MIMEText(html_body, "html"))

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
        server.starttls()
        server.login(SMTP_USER, password)
        server.sendmail(SMTP_USER, [TO_ADDR], msg.as_string())

    print(f"Email sent: {subject}")


def main():
    # Read env vars from backlog-md callback
    task_id = os.environ.get("TASK_ID", "")
    old_status = os.environ.get("OLD_STATUS", "")
    new_status = os.environ.get("NEW_STATUS", "")
    task_title = os.environ.get("TASK_TITLE", "")

    # Only notify on completion
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

    # Build and send email
    subject = f"[DONE] {task_id}: {task_title}"
    html_body = build_html_email(task_id, task_title, project, output_products, links_to_test, criteria)
    text_body = build_text_email(task_id, task_title, project, output_products, links_to_test, criteria)
    send_email(subject, html_body, text_body)


if __name__ == "__main__":
    main()
