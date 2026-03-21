"""
Kuma Alert Agent — monitors Uptime Kuma for service outages,
diagnoses via Claude CLI, proposes fixes with email-based approval flow.

Flow: Poll Kuma -> Detect DOWN -> Diagnose (Claude read-only) -> Email alert
   -> Wait for approval reply -> Execute fix (Claude auto-accept) -> Report
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
import uuid
from datetime import datetime, timedelta, timezone
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path

from uptime_kuma_api import UptimeKumaApi

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("/data/agent.log"),
    ],
)
log = logging.getLogger("kuma-alert-agent")

# ─── Configuration ─────────────────────────────────────────────────────

KUMA_URL = os.environ["KUMA_URL"]
KUMA_USERNAME = os.environ["KUMA_USERNAME"]
KUMA_PASSWORD = os.environ["KUMA_PASSWORD"]

IMAP_HOST = os.environ["IMAP_HOST"]
IMAP_PORT = int(os.environ.get("IMAP_PORT", "993"))
IMAP_USER = os.environ["IMAP_USER"]
IMAP_PASS = os.environ["IMAP_PASS"]

SMTP_HOST = os.environ["SMTP_HOST"]
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ["SMTP_USER"]
SMTP_PASS = os.environ["SMTP_PASS"]
SMTP_FROM = os.environ.get("SMTP_FROM", SMTP_USER)

ALERT_TO = os.environ.get("ALERT_TO", "jeff@jeffemmett.com")
ALLOWED_APPROVERS = [
    s.strip().lower()
    for s in os.environ.get("ALLOWED_APPROVERS", "jeff@jeffemmett.com").split(",")
    if s.strip()
]

CHECK_INTERVAL = int(os.environ.get("CHECK_INTERVAL", "60"))
ALERT_THRESHOLD = int(os.environ.get("ALERT_THRESHOLD", "3"))  # consecutive checks
MAX_BUDGET_DIAGNOSE = os.environ.get("MAX_BUDGET_DIAGNOSE", "0.50")
MAX_BUDGET_FIX = os.environ.get("MAX_BUDGET_FIX", "2.00")

CLAUDE_CONTAINER = os.environ.get("CLAUDE_CONTAINER", "claude-dev")
CLAUDE_WORKDIR = os.environ.get("CLAUDE_WORKDIR", "/opt/apps")

DATA_DIR = Path("/data")
INCIDENTS_FILE = DATA_DIR / "incidents.json"
AUDIT_LOG = DATA_DIR / "audit.json"
STATE_FILE = DATA_DIR / "state.json"

# Runtime state
_down_counts: dict[int, int] = {}
_processed_replies: set[str] = set()


# ─── Persistence ───────────────────────────────────────────────────────

def load_json(path: Path) -> dict:
    if path.exists():
        try:
            return json.loads(path.read_text())
        except json.JSONDecodeError:
            return {}
    return {}


def save_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, indent=2))


def audit(entry: dict) -> None:
    entries = []
    if AUDIT_LOG.exists():
        try:
            entries = json.loads(AUDIT_LOG.read_text())
        except json.JSONDecodeError:
            entries = []
    entry["timestamp"] = datetime.now(timezone.utc).isoformat()
    entries.append(entry)
    if len(entries) > 500:
        entries = entries[-500:]
    save_json(AUDIT_LOG, entries)


# ─── Uptime Kuma API ──────────────────────────────────────────────────

_KUMA_FETCH_SCRIPT = '''
import json, os, sys
from uptime_kuma_api import UptimeKumaApi
api = UptimeKumaApi(os.environ["KUMA_URL"], timeout=30, wait_events=3)
try:
    api.login(os.environ["KUMA_USERNAME"], os.environ["KUMA_PASSWORD"])
    monitors = api.get_monitors()
    heartbeats = api.get_heartbeats()
    results = {}
    for m in monitors:
        mid = m["id"]
        beats = heartbeats.get(mid, [])
        latest = beats[-1] if beats else None
        if isinstance(latest, list):
            latest = latest[-1] if latest else None
        if latest and not isinstance(latest, dict):
            latest = None
        results[mid] = {
            "id": mid,
            "name": m.get("name", f"Monitor {mid}"),
            "url": m.get("url", ""),
            "type": str(m.get("type", "")),
            "active": m.get("active", True),
            "status": latest["status"] if latest else None,
            "status_msg": latest.get("msg", "") if latest else "",
            "last_check": latest.get("time", "") if latest else "",
        }
    json.dump(results, sys.stdout)
finally:
    try:
        api.disconnect()
    except:
        pass
'''


def get_monitor_statuses() -> dict:
    """Fetch monitor statuses via a subprocess to enforce hard timeout."""
    try:
        result = subprocess.run(
            [sys.executable, "-c", _KUMA_FETCH_SCRIPT],
            capture_output=True, text=True, timeout=45,
            env={**os.environ},
        )
        if result.returncode != 0:
            log.warning("Kuma fetch subprocess failed (rc=%d): %s",
                        result.returncode, result.stderr[:300])
            return {}
        data = json.loads(result.stdout)
        # Convert string keys back to int
        return {int(k): v for k, v in data.items()}
    except subprocess.TimeoutExpired:
        log.warning("Kuma fetch subprocess timed out after 45s")
        return {}
    except Exception as e:
        log.error("Kuma API error: %s", e)
        return {}


# ─── Claude CLI ────────────────────────────────────────────────────────

DIAGNOSE_PROMPT_TMPL = """SERVICE ALERT: "{name}" is DOWN

URL: {url}
Monitor type: {type}
Error: {status_msg}
Last check: {last_check}

Diagnose this outage. Check Docker container status, logs, and system resources.
Identify the root cause and propose a specific fix."""

DIAGNOSE_SYSTEM = """You are a server ops agent diagnosing a service outage on a Netcup RS 8000 running 40+ Docker services behind Traefik.

RULES:
1. Run diagnostic commands: docker ps, docker logs, docker inspect, docker stats, df, free, curl
2. Do NOT run any destructive or modifying commands (no restart, stop, rm, compose, edit)
3. ONLY diagnose — do not fix anything

End your response with EXACTLY this format (each on its own line):
CONTAINER: <container_name or UNKNOWN>
DIAGNOSIS: <one-line summary of the problem>
PROPOSED_FIX: <exact commands to run, separated by semicolons>
RISK: <LOW|MEDIUM|HIGH>"""

FIX_SYSTEM = """You are a server ops agent executing an APPROVED fix on a Netcup RS 8000.
The server owner has explicitly approved this fix via email.

Execute the fix, verify the service recovers, and report results.
End your response with:
RESULT: <SUCCESS|PARTIAL|FAILED>
SUMMARY: <what happened>"""


def run_claude(prompt: str, system: str, budget: str, timeout: int = 300) -> str:
    cmd = [
        "docker", "exec", "-w", CLAUDE_WORKDIR, CLAUDE_CONTAINER,
        "claude", "-p", prompt,
        "--output-format", "text",
        "--max-budget-usd", budget,
        "--permission-mode", "auto",
        "--append-system-prompt", system,
    ]
    log.info("Running Claude CLI (budget=$%s)", budget)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        if result.returncode != 0:
            log.error("Claude error (rc=%d): %s", result.returncode, result.stderr[:500])
            return f"[Claude error: exit code {result.returncode}]\n{result.stderr[:500]}"
        return result.stdout.strip() or "[Empty response]"
    except subprocess.TimeoutExpired:
        return f"[Claude timed out after {timeout}s]"
    except Exception as e:
        return f"[Error: {e}]"


def parse_diagnosis(response: str) -> dict:
    result = {
        "container": "UNKNOWN",
        "diagnosis": "",
        "proposed_fix": "",
        "risk": "UNKNOWN",
        "full_response": response,
    }
    for line in response.split("\n"):
        line = line.strip()
        if line.startswith("CONTAINER:"):
            result["container"] = line.split(":", 1)[1].strip()
        elif line.startswith("DIAGNOSIS:"):
            result["diagnosis"] = line.split(":", 1)[1].strip()
        elif line.startswith("PROPOSED_FIX:"):
            result["proposed_fix"] = line.split(":", 1)[1].strip()
        elif line.startswith("RISK:"):
            result["risk"] = line.split(":", 1)[1].strip()
    return result


# ─── Email ─────────────────────────────────────────────────────────────

def send_email(to: str, subject: str, body: str, message_id: str | None = None,
               in_reply_to: str | None = None, references: str | None = None) -> str | None:
    msg = MIMEMultipart("alternative")
    msg["From"] = f"Jeff's Claude Agent <{SMTP_FROM}>"
    msg["To"] = to
    msg["Subject"] = subject
    if message_id:
        msg["Message-ID"] = message_id
    if in_reply_to:
        msg["In-Reply-To"] = in_reply_to
    if references:
        msg["References"] = references
    msg.attach(MIMEText(body, "plain"))

    try:
        server = smtplib.SMTP(SMTP_HOST, SMTP_PORT)
        server.starttls()
        server.login(SMTP_USER, SMTP_PASS)
        server.sendmail(SMTP_USER, [to], msg.as_string())
        server.quit()
        log.info("Email sent to %s: %s", to, subject)
        return message_id
    except Exception as e:
        log.error("SMTP error: %s", e)
        return None


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


def send_alert_email(monitor_info: dict, diagnosis: dict, incident_id: str) -> str | None:
    subject = f"[KUMA] {monitor_info['name']} is DOWN (ID: {incident_id})"
    message_id = f"<kuma-{incident_id}@jeffemmett.com>"

    body = f"""SERVICE DOWN: {monitor_info['name']}
URL: {monitor_info.get('url', 'N/A')}
Down since: {monitor_info.get('last_check', 'N/A')}
Error: {monitor_info.get('status_msg', 'N/A')}

{'=' * 55}
 DIAGNOSIS
{'=' * 55}
Container: {diagnosis.get('container', 'UNKNOWN')}
Issue: {diagnosis.get('diagnosis', 'See analysis below')}
Risk: {diagnosis.get('risk', 'UNKNOWN')}

{'=' * 55}
 PROPOSED FIX
{'=' * 55}
{diagnosis.get('proposed_fix', 'No fix proposed')}

{'=' * 55}
 FULL ANALYSIS
{'=' * 55}
{diagnosis.get('full_response', 'N/A')[:3000]}

{'=' * 55}

Reply APPROVE to execute the proposed fix.
Reply REJECT to dismiss this alert.
Reply with custom instructions to override the fix.

--
Kuma Alert Agent (claude@jeffemmett.com)
"""
    return send_email(ALERT_TO, subject, body, message_id=message_id)


def send_recovery_email(monitor_name: str, incident_id: str, was_fixed: bool) -> None:
    how = "after automated fix" if was_fixed else "on its own (no fix needed)"
    subject = f"[KUMA] {monitor_name} is BACK UP (ID: {incident_id})"
    body = f"""SERVICE RECOVERED: {monitor_name}

Recovered {how}.
Time: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}

--
Kuma Alert Agent (claude@jeffemmett.com)
"""
    send_email(ALERT_TO, subject, body)


def send_fix_result(incident: dict, result: str) -> None:
    iid = incident["id"]
    alert_msg = f"<kuma-{iid}@jeffemmett.com>"
    subject = f"Re: [KUMA] {incident['monitor_name']} is DOWN (ID: {iid})"
    body = f"""FIX EXECUTED: {incident['monitor_name']}

{'=' * 55}
 RESULT
{'=' * 55}
{result[:5000]}

{'=' * 55}

Monitoring for recovery. If the issue persists, a new alert will follow.

--
Kuma Alert Agent (claude@jeffemmett.com)
"""
    send_email(ALERT_TO, subject, body, in_reply_to=alert_msg, references=alert_msg)


# ─── Approval Detection ───────────────────────────────────────────────

def check_for_approvals(incidents: dict) -> list[dict]:
    """Search IMAP for replies to pending alert emails."""
    pending = {k: v for k, v in incidents.items() if v.get("status") == "alerted"}
    if not pending:
        return []

    approvals = []
    try:
        mail = imaplib.IMAP4_SSL(IMAP_HOST, IMAP_PORT)
        mail.login(IMAP_USER, IMAP_PASS)
        mail.select("INBOX")

        since = (datetime.now() - timedelta(days=7)).strftime("%d-%b-%Y")
        for approver in ALLOWED_APPROVERS:
            status, data = mail.search(None, f'(FROM "{approver}" SUBJECT "[KUMA]" SINCE {since})')
            if status != "OK" or not data[0]:
                continue

            for msg_num in data[0].split():
                status, msg_data = mail.fetch(msg_num, "(BODY.PEEK[])")
                if status != "OK":
                    continue

                msg = email.message_from_bytes(msg_data[0][1])
                reply_id = msg.get("Message-ID", "")

                if reply_id in _processed_replies:
                    continue

                in_reply_to = msg.get("In-Reply-To", "")
                refs = msg.get("References", "")

                for mid, inc in pending.items():
                    expected = f"<kuma-{inc['id']}@jeffemmett.com>"
                    if expected in in_reply_to or expected in refs:
                        body = extract_plain_text(msg)
                        approvals.append({
                            "incident_id": inc["id"],
                            "monitor_id": mid,
                            "body": body,
                            "sender": approver,
                            "reply_id": reply_id,
                        })
                        _processed_replies.add(reply_id)
                        break

        mail.logout()
    except Exception as e:
        log.error("IMAP approval check error: %s", e)

    return approvals


def parse_approval(body: str) -> tuple[str, str]:
    """Returns (action, custom_instructions). action: approve|reject|custom"""
    lines = [l for l in body.split("\n")
             if not l.strip().startswith(">") and not l.strip().startswith("On ")]
    clean = "\n".join(lines).strip()

    first_line = ""
    for line in clean.split("\n"):
        line = line.strip()
        if line and not line.startswith("--"):
            first_line = line
            break

    fl = first_line.lower()
    if any(kw in fl for kw in ["approve", "yes", "go ahead", "fix it", "do it", "proceed"]):
        return "approve", ""
    if any(kw in fl for kw in ["reject", "no", "dismiss", "ignore", "skip"]):
        return "reject", ""
    return "custom", clean


# ─── Incident Lifecycle ───────────────────────────────────────────────

def create_incident(monitor_info: dict, incidents: dict) -> None:
    iid = str(uuid.uuid4())[:8]
    mid = str(monitor_info["id"])
    log.info("NEW INCIDENT %s: '%s' is DOWN", iid, monitor_info["name"])

    # Diagnose
    prompt = DIAGNOSE_PROMPT_TMPL.format(**monitor_info)
    raw = run_claude(prompt, DIAGNOSE_SYSTEM, MAX_BUDGET_DIAGNOSE, timeout=180)
    diag = parse_diagnosis(raw)
    log.info("Diagnosis: %s | Fix: %s | Risk: %s",
             diag["diagnosis"][:80], diag["proposed_fix"][:80], diag["risk"])

    # Alert
    msg_id = send_alert_email(monitor_info, diag, iid)

    incidents[mid] = {
        "id": iid,
        "monitor_id": mid,
        "monitor_name": monitor_info["name"],
        "monitor_url": monitor_info.get("url", ""),
        "status": "alerted",
        "container": diag.get("container", "UNKNOWN"),
        "diagnosis": diag.get("diagnosis", ""),
        "proposed_fix": diag.get("proposed_fix", ""),
        "risk": diag.get("risk", "UNKNOWN"),
        "full_diagnosis": diag.get("full_response", "")[:5000],
        "alert_msg_id": msg_id,
        "created": datetime.now(timezone.utc).isoformat(),
        "updated": datetime.now(timezone.utc).isoformat(),
    }
    save_json(INCIDENTS_FILE, incidents)
    audit({"action": "incident_created", "id": iid, "monitor": monitor_info["name"]})


def handle_approval(approval: dict, incidents: dict) -> None:
    mid = approval["monitor_id"]
    incident = incidents.get(mid)
    if not incident:
        return

    action, custom = parse_approval(approval["body"])
    log.info("APPROVAL for %s: action=%s", incident["id"], action)

    if action == "approve":
        incident["status"] = "executing"
        incident["updated"] = datetime.now(timezone.utc).isoformat()
        save_json(INCIDENTS_FILE, incidents)

        result = run_claude(
            f'Execute this APPROVED fix for "{incident["monitor_name"]}":\n\n'
            f'{incident["proposed_fix"]}\n\n'
            f'Container: {incident.get("container", "unknown")}\n'
            f'Original diagnosis: {incident["diagnosis"]}',
            FIX_SYSTEM, MAX_BUDGET_FIX, timeout=300,
        )
        send_fix_result(incident, result)
        incident["status"] = "fix_executed"
        incident["fix_result"] = result[:5000]

    elif action == "reject":
        incident["status"] = "rejected"
        log.info("Incident %s rejected", incident["id"])

    elif action == "custom":
        incident["status"] = "executing"
        incident["proposed_fix"] = custom
        incident["updated"] = datetime.now(timezone.utc).isoformat()
        save_json(INCIDENTS_FILE, incidents)

        result = run_claude(
            f'Execute these CUSTOM instructions for "{incident["monitor_name"]}":\n\n'
            f'{custom}\n\n'
            f'Original diagnosis: {incident["diagnosis"]}',
            FIX_SYSTEM, MAX_BUDGET_FIX, timeout=300,
        )
        send_fix_result(incident, result)
        incident["status"] = "fix_executed"
        incident["fix_result"] = result[:5000]

    incident["updated"] = datetime.now(timezone.utc).isoformat()
    save_json(INCIDENTS_FILE, incidents)
    audit({"action": f"incident_{action}", "id": incident["id"],
           "monitor": incident["monitor_name"], "by": approval["sender"]})


def handle_recovery(mid: str, monitor_info: dict, incidents: dict) -> None:
    incident = incidents.get(mid)
    if not incident:
        return
    was_fixed = incident.get("status") in ("fix_executed", "executing")
    log.info("RECOVERED: '%s' (incident %s)", monitor_info["name"], incident["id"])

    send_recovery_email(monitor_info["name"], incident["id"], was_fixed)
    audit({"action": "resolved", "id": incident["id"],
           "monitor": monitor_info["name"], "was_fixed": was_fixed})

    del incidents[mid]
    save_json(INCIDENTS_FILE, incidents)
    _down_counts.pop(int(mid), None)


# ─── Main Loop ─────────────────────────────────────────────────────────

def main() -> None:
    log.info("Kuma Alert Agent starting")
    log.info("Kuma: %s | Alerts to: %s | Approvers: %s",
             KUMA_URL, ALERT_TO, ALLOWED_APPROVERS)
    log.info("Check interval: %ds | Alert after: %d consecutive downs",
             CHECK_INTERVAL, ALERT_THRESHOLD)

    incidents = load_json(INCIDENTS_FILE)
    state = load_json(STATE_FILE)
    _processed_replies.update(state.get("processed_replies", []))

    cycle = 0
    while True:
        try:
            # ── Poll monitors ──
            log.info("Polling Kuma...")
            monitors = get_monitor_statuses()
            log.info("Got %d monitors", len(monitors))
            if monitors:
                for mid_int, info in monitors.items():
                    if not info.get("active", True):
                        continue
                    mid = str(mid_int)
                    status = info.get("status")

                    if status == 0:  # DOWN
                        _down_counts[mid_int] = _down_counts.get(mid_int, 0) + 1
                        if mid not in incidents and _down_counts[mid_int] >= ALERT_THRESHOLD:
                            create_incident(info, incidents)

                    elif status == 1:  # UP
                        _down_counts.pop(mid_int, None)
                        if mid in incidents:
                            handle_recovery(mid, info, incidents)
            else:
                log.warning("No monitor data from Kuma (API unreachable?)")

            # ── Check approvals ──
            approvals = check_for_approvals(incidents)
            for approval in approvals:
                handle_approval(approval, incidents)

            # ── Maintenance (every ~60 cycles) ──
            cycle += 1
            if cycle % 60 == 0:
                now = datetime.now(timezone.utc)
                stale = [mid for mid, inc in incidents.items()
                         if (now - datetime.fromisoformat(inc["updated"])).total_seconds() > 86400
                         and inc["status"] in ("rejected", "fix_executed")]
                for mid in stale:
                    log.info("Cleaning stale incident %s", incidents[mid]["id"])
                    del incidents[mid]
                if stale:
                    save_json(INCIDENTS_FILE, incidents)

                if len(_processed_replies) > 1000:
                    _processed_replies.clear()

                save_json(STATE_FILE, {"processed_replies": list(_processed_replies)[-500:]})

        except Exception as e:
            log.error("Loop error: %s", e, exc_info=True)

        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    main()
