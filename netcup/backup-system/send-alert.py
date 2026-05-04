#!/usr/bin/env python3
"""Send email alerts for backup failures via Mailcow postfix sendmail.

Uses docker exec to pipe email through the postfix container's sendmail,
bypassing SMTP auth (which has stale credentials as of 2026-03).
"""

import subprocess
import sys
import socket
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime

MAIL_FROM = "claude@jeffemmett.com"
ALERT_TO = "jeffemmett@gmail.com"
POSTFIX_CONTAINER = "mailcowdockerized-postfix-mailcow-1"


def send_alert(subject, body):
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"Netcup Backup Monitor <{MAIL_FROM}>"
    msg["To"] = ALERT_TO

    # Plain text version
    msg.attach(MIMEText(body, "plain"))

    # HTML version
    html_body = f"""<html><body>
<h2 style="color: #cc0000;">{subject}</h2>
<pre style="background: #f5f5f5; padding: 15px; border-radius: 5px; font-size: 14px;">{body}</pre>
<hr>
<p style="color: #666; font-size: 12px;">
    Server: {socket.gethostname()} | Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
</p>
</body></html>"""
    msg.attach(MIMEText(html_body, "html"))

    email_bytes = msg.as_string().encode("utf-8")

    try:
        result = subprocess.run(
            ["docker", "exec", "-i", POSTFIX_CONTAINER,
             "sendmail", "-f", MAIL_FROM, ALERT_TO],
            input=email_bytes,
            capture_output=True,
            timeout=30,
        )
        if result.returncode == 0:
            print(f"Alert sent to {ALERT_TO}")
            return True
        else:
            print(f"sendmail failed (rc={result.returncode}): {result.stderr.decode()}", file=sys.stderr)
            return False
    except Exception as e:
        print(f"Failed to send alert: {e}", file=sys.stderr)
        return False


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <subject> <body>")
        sys.exit(1)

    subject = sys.argv[1]
    body = " ".join(sys.argv[2:])

    success = send_alert(subject, body)
    sys.exit(0 if success else 1)
