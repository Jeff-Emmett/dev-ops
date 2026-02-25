#!/usr/bin/env python3
"""Send email alerts for backup failures via Mailcow SMTP."""

import smtplib
import os
import sys
import socket
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime

# SMTP config - reads password from credential file (never hardcode)
# Credential file: /opt/secrets/mailcow/smtp-noreply.env
SMTP_HOST = "mail.rmail.online"
SMTP_PORT = 587
SMTP_USER = "noreply@jeffemmett.com"
SMTP_FROM = "noreply@jeffemmett.com"
ALERT_TO = "jeff@jeffemmett.com"

def _load_smtp_password():
    """Load SMTP password from credential file."""
    cred_file = "/opt/secrets/mailcow/smtp-noreply.env"
    try:
        with open(cred_file) as f:
            for line in f:
                if line.startswith("SMTP_PASS="):
                    return line.strip().split("=", 1)[1]
    except FileNotFoundError:
        pass
    return os.environ.get("SMTP_PASS", "")

SMTP_PASS = _load_smtp_password()

def send_alert(subject, body):
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"Netcup Backup Monitor <{SMTP_FROM}>"
    msg["To"] = ALERT_TO

    # Plain text version
    msg.attach(MIMEText(body, "plain"))

    # HTML version
    html_body = f"""<html><body>
<h2 style="color: #cc0000;">{subject}</h2>
<pre style="background: #f5f5f5; padding: 15px; border-radius: 5px; font-size: 14px;">{body}</pre>
<hr>
<p style="color: #666; font-size: 12px;">
    Server: {socket.gethostname()} | Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} |
    <a href="https://vpn-admin.jeffemmett.com">Headplane</a>
</p>
</body></html>"""
    msg.attach(MIMEText(html_body, "html"))

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASS)
            server.sendmail(SMTP_FROM, [ALERT_TO], msg.as_string())
        print(f"Alert sent to {ALERT_TO}")
        return True
    except Exception as e:
        print(f"Failed to send alert: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <subject> <body>")
        print(f"   or: pipe body via stdin: echo 'body' | {sys.argv[0]} <subject>")
        sys.exit(1)

    subject = sys.argv[1]
    if len(sys.argv) > 2:
        body = " ".join(sys.argv[2:])
    else:
        body = sys.stdin.read()

    success = send_alert(subject, body)
    sys.exit(0 if success else 1)
