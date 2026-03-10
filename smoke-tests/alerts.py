#!/usr/bin/env python3
"""
Email alerting for smoke test failures via Mailcow SMTP.
Uses mail.rmail.online:587 with STARTTLS.
"""
import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

SMTP_HOST = 'mail.rmail.online'
SMTP_PORT = 587
SMTP_USER = 'noreply@rmail.online'
ALERT_TO = 'jeff@jeffemmett.com'
SMTP_ENV_FILE = os.environ.get(
    'SMTP_ENV_FILE', '/opt/secrets/mailcow/smtp-noreply.env'
)


def _get_smtp_password():
    """Read SMTP password from env file or environment."""
    password = os.environ.get('SMTP_PASSWORD')
    if password:
        return password

    if os.path.exists(SMTP_ENV_FILE):
        with open(SMTP_ENV_FILE) as f:
            for line in f:
                line = line.strip()
                if line.startswith('SMTP_PASSWORD='):
                    return line.split('=', 1)[1].strip().strip('"').strip("'")

    raise RuntimeError(
        f"SMTP password not found in env or {SMTP_ENV_FILE}"
    )


def send_failure_alert(site_name, url, exit_code, duration):
    """Send HTML + plaintext failure alert email."""
    subject = f"[SMOKE FAIL] {site_name} — post-deploy check failed"

    plain = f"""Smoke test FAILED for {site_name}

URL: {url}
Exit code: {exit_code}
Duration: {duration:.1f}s

Check deploy logs on Netcup:
  docker logs deploy-webhook --tail 50
  ls /var/log/smoke-tests/{site_name}_*
"""

    html = f"""\
<html>
<body style="font-family: monospace; background: #1a1a1a; color: #e0e0e0; padding: 20px;">
  <h2 style="color: #ff4444;">Smoke Test Failed: {site_name}</h2>
  <table style="border-collapse: collapse;">
    <tr><td style="padding: 4px 12px; color: #888;">URL</td><td><a href="{url}" style="color: #6cb6ff;">{url}</a></td></tr>
    <tr><td style="padding: 4px 12px; color: #888;">Exit code</td><td style="color: #ff4444;">{exit_code}</td></tr>
    <tr><td style="padding: 4px 12px; color: #888;">Duration</td><td>{duration:.1f}s</td></tr>
  </table>
  <p style="color: #888; margin-top: 16px; font-size: 12px;">
    Check logs: <code>ls /var/log/smoke-tests/{site_name}_*</code>
  </p>
</body>
</html>
"""

    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = SMTP_USER
    msg['To'] = ALERT_TO
    msg.attach(MIMEText(plain, 'plain'))
    msg.attach(MIMEText(html, 'html'))

    password = _get_smtp_password()
    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
        server.starttls()
        server.login(SMTP_USER, password)
        server.send_message(msg)
