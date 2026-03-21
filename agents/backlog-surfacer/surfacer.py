#!/usr/bin/env python3
"""Backlog Surfacing Agent — scans project backlogs and surfaces relevant tasks."""

import glob
import os
import re
import smtplib
import sys
from collections import defaultdict
from datetime import datetime, timedelta
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path

import yaml


def load_config(path: str = None) -> dict:
    if path is None:
        path = os.environ.get(
            "SURFACER_CONFIG",
            str(Path(__file__).parent / "config.yml"),
        )
    with open(path) as f:
        return yaml.safe_load(f)


def parse_task_file(filepath: str) -> dict | None:
    """Parse a backlog task markdown file with YAML frontmatter."""
    try:
        with open(filepath) as f:
            content = f.read()
    except (OSError, UnicodeDecodeError):
        return None

    # Extract YAML frontmatter
    match = re.match(r"^---\s*\n(.*?)\n---\s*\n(.*)$", content, re.DOTALL)
    if not match:
        return None

    try:
        meta = yaml.safe_load(match.group(1)) or {}
    except yaml.YAMLError:
        return None

    meta["_body"] = match.group(2)
    meta["_file"] = filepath

    # Derive project name from path
    # Handles: /home/jeffe/Github/<project>/backlog/tasks/...
    #          /data/apps/<project>/backlog/tasks/...
    #          /data/websites/<project>/backlog/tasks/...
    parts = Path(filepath).parts
    meta["_project"] = "unknown"
    for marker in ("Github", "github", "apps", "websites"):
        try:
            idx = parts.index(marker)
            meta["_project"] = parts[idx + 1]
            break
        except (ValueError, IndexError):
            continue

    return meta


def scan_backlogs(config: dict) -> list[dict]:
    """Scan all configured backlog paths and return parsed tasks."""
    tasks = []
    for pattern in config.get("scan_paths", {}).get("local", []):
        task_dirs = glob.glob(os.path.join(pattern, "tasks"))
        for task_dir in task_dirs:
            for f in sorted(Path(task_dir).glob("*.md")):
                task = parse_task_file(str(f))
                if task:
                    tasks.append(task)
    return tasks


def parse_date(val) -> datetime | None:
    """Parse various date formats from frontmatter."""
    if val is None:
        return None
    if isinstance(val, datetime):
        return val
    s = str(val).strip().strip("'\"")
    for fmt in ("%Y-%m-%d %H:%M", "%Y-%m-%d", "%Y/%m/%d"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            continue
    return None


def filter_active(tasks: list[dict]) -> list[dict]:
    """Return tasks that are not Done/completed."""
    return [
        t for t in tasks
        if str(t.get("status", "")).lower() not in ("done", "completed", "✔ done")
    ]


def high_priority(tasks: list[dict]) -> list[dict]:
    return [t for t in tasks if str(t.get("priority", "")).lower() == "high"]


def stale_in_progress(tasks: list[dict], days: int = 3) -> list[dict]:
    """Tasks in progress for more than N days."""
    cutoff = datetime.now() - timedelta(days=days)
    result = []
    for t in tasks:
        status = str(t.get("status", "")).lower()
        if status not in ("in progress", "◒ in progress"):
            continue
        updated = parse_date(t.get("updated_date") or t.get("created_date"))
        if updated and updated < cutoff:
            result.append(t)
    return result


def stale_todo(tasks: list[dict], days: int = 30) -> list[dict]:
    """Tasks in To Do for more than N days."""
    cutoff = datetime.now() - timedelta(days=days)
    result = []
    for t in tasks:
        status = str(t.get("status", "")).lower()
        if status not in ("to do", "○ to do"):
            continue
        created = parse_date(t.get("created_date"))
        if created and created < cutoff:
            result.append(t)
    return result


def recently_completed(tasks: list[dict], days: int = 7) -> list[dict]:
    """Tasks completed in the last N days."""
    cutoff = datetime.now() - timedelta(days=days)
    result = []
    for t in tasks:
        status = str(t.get("status", "")).lower()
        if status not in ("done", "completed", "✔ done"):
            continue
        updated = parse_date(t.get("updated_date"))
        if updated and updated > cutoff:
            result.append(t)
    return result


def upcoming_deadlines(tasks: list[dict], days: int = 14) -> list[dict]:
    """Tasks with due dates within the next N days (not Done), sorted soonest first."""
    cutoff = datetime.now() + timedelta(days=days)
    result = []
    for t in tasks:
        status = str(t.get("status", "")).lower()
        if status in ("done", "completed", "✔ done"):
            continue
        due = parse_date(t.get("due_date"))
        if due and due <= cutoff:
            result.append(t)
    return sorted(result, key=lambda t: parse_date(t.get("due_date")))


def format_task(t: dict, show_project: bool = True) -> str:
    """Format a single task as a markdown line."""
    tid = t.get("id", "?")
    title = t.get("title", "Untitled")
    priority = t.get("priority", "")
    project = t.get("_project", "")
    status = t.get("status", "")
    pri_badge = f"[{priority.upper()}]" if priority else ""
    proj_part = f" ({project})" if show_project else ""
    return f"  - {pri_badge} **{tid}** — {title}{proj_part} _{status}_"


def format_task_with_due(t: dict, show_project: bool = True) -> str:
    """Format a task line with due date urgency indicator."""
    base = format_task(t, show_project=show_project)
    due = parse_date(t.get("due_date"))
    if not due:
        return base
    days = (due - datetime.now()).days
    if days < 0:
        return f"{base} — **OVERDUE by {abs(days)}d**"
    elif days == 0:
        return f"{base} — **DUE TODAY**"
    elif days <= 3:
        return f"{base} — due in {days}d"
    else:
        return f"{base} — due {due.strftime('%b %d')}"


def group_tasks_by_project(tasks: list[dict]) -> dict:
    """Group tasks into {project: [tasks]} preserving order."""
    groups = defaultdict(list)
    for t in tasks:
        groups[t.get("_project", "unknown")].append(t)
    return dict(groups)


def format_section_by_project(title: str, tasks: list[dict], formatter=None) -> str:
    """Format a section with tasks grouped under project subheadings."""
    if not tasks:
        return ""
    if formatter is None:
        formatter = format_task
    lines = [f"## {title} ({len(tasks)} tasks)", ""]
    groups = group_tasks_by_project(tasks)
    for proj, proj_tasks in sorted(groups.items(), key=lambda x: -len(x[1])):
        lines.append(f"### {proj}")
        for t in proj_tasks:
            lines.append(formatter(t, show_project=False))
        lines.append("")
    return "\n".join(lines)


def generate_morning_briefing(tasks: list[dict], config: dict) -> str:
    """Generate the morning briefing report."""
    rules = config.get("rules", {})
    active = filter_active(tasks)

    lines = [
        f"# Backlog Briefing — {datetime.now().strftime('%A, %B %d %Y')}",
        "",
    ]

    # Upcoming deadlines at the very top
    deadline_days = rules.get("upcoming_deadline_days", 14)
    upcoming = upcoming_deadlines(active, deadline_days)
    if upcoming:
        lines.append(format_section_by_project(
            "Upcoming Deadlines",
            upcoming,
            formatter=format_task_with_due,
        ))

    # High priority grouped by project
    hp = high_priority(active)
    if hp:
        lines.append(format_section_by_project("High Priority", hp))

    # Stale in-progress grouped by project
    stale_ip = stale_in_progress(active, rules.get("stale_in_progress_days", 3))
    if stale_ip:
        def fmt_stale(t, show_project=True):
            updated = parse_date(t.get("updated_date") or t.get("created_date"))
            age = (datetime.now() - updated).days if updated else "?"
            return f"{format_task(t, show_project=show_project)} — {age}d ago"
        lines.append(format_section_by_project(
            f"Stale In Progress (>{rules.get('stale_in_progress_days', 3)} days)",
            stale_ip,
            formatter=fmt_stale,
        ))

    # Summary
    by_project = defaultdict(int)
    for t in active:
        by_project[t.get("_project", "unknown")] += 1

    lines.append("## Summary")
    lines.append(f"- **{len(active)}** active tasks across **{len(by_project)}** projects")
    for proj, count in sorted(by_project.items(), key=lambda x: -x[1]):
        lines.append(f"  - {proj}: {count}")
    lines.append("")

    return "\n".join(lines)


def generate_weekly_review(tasks: list[dict], config: dict) -> str:
    """Generate the weekly review report."""
    rules = config.get("rules", {})
    active = filter_active(tasks)
    completed = recently_completed(tasks, days=7)

    lines = [
        f"# Weekly Review — {datetime.now().strftime('%A, %B %d %Y')}",
        "",
    ]

    # Upcoming deadlines at the top
    deadline_days = rules.get("upcoming_deadline_days", 14)
    upcoming = upcoming_deadlines(active, deadline_days)
    if upcoming:
        lines.append(format_section_by_project(
            "Upcoming Deadlines",
            upcoming,
            formatter=format_task_with_due,
        ))

    # Completed grouped by project
    if completed:
        lines.append(format_section_by_project("Completed This Week", completed))

    # Stuck tasks grouped by project
    stale_ip = stale_in_progress(active, rules.get("stale_in_progress_days", 3))
    if stale_ip:
        lines.append(format_section_by_project("Stuck / No Movement", stale_ip))

    # Velocity
    lines.append("## Velocity")
    lines.append(f"- Completed: **{len(completed)}**")
    lines.append(f"- Still active: **{len(active)}**")
    lines.append("")

    return "\n".join(lines)


def generate_monthly_audit(tasks: list[dict], config: dict) -> str:
    """Generate the monthly stale task audit."""
    rules = config.get("rules", {})
    active = filter_active(tasks)
    stale = stale_todo(active, rules.get("stale_todo_days", 30))

    lines = [
        f"# Monthly Audit — {datetime.now().strftime('%B %Y')}",
        "",
    ]

    if stale:
        def fmt_stale_age(t, show_project=True):
            created = parse_date(t.get("created_date"))
            age = (datetime.now() - created).days if created else "?"
            return f"{format_task(t, show_project=show_project)} — created {age}d ago"

        lines.append("_Consider closing, archiving, or reprioritizing these:_")
        lines.append("")
        lines.append(format_section_by_project(
            f"Stale To Do (>{rules.get('stale_todo_days', 30)} days)",
            stale,
            formatter=fmt_stale_age,
        ))

    # Projects with zero activity
    by_project = defaultdict(list)
    for t in tasks:
        by_project[t.get("_project", "unknown")].append(t)

    inactive = []
    for proj, proj_tasks in by_project.items():
        has_recent = any(
            parse_date(t.get("updated_date")) and parse_date(t.get("updated_date")) > datetime.now() - timedelta(days=30)
            for t in proj_tasks
        )
        if not has_recent:
            inactive.append(proj)

    if inactive:
        lines.append(f"## Inactive Projects ({len(inactive)})")
        for proj in sorted(inactive):
            lines.append(f"  - {proj}")
        lines.append("")

    lines.append("## Summary")
    lines.append(f"- **{len(active)}** active tasks total")
    lines.append(f"- **{len(stale)}** stale (> {rules.get('stale_todo_days', 30)}d in To Do)")
    lines.append(f"- **{len(inactive)}** projects with no activity this month")
    lines.append("")

    return "\n".join(lines)


def send_email(report: str, subject: str, config: dict) -> None:
    """Send report via SMTP email."""
    for notif in config.get("notifications", []):
        if notif.get("type") != "email":
            continue

        smtp_host = notif.get("smtp_host", os.environ.get("SMTP_HOST", "localhost"))
        smtp_port = int(notif.get("smtp_port", os.environ.get("SMTP_PORT", "587")))
        smtp_user = notif.get("smtp_user", os.environ.get("SMTP_USER", ""))
        smtp_pass = notif.get("smtp_pass", os.environ.get("SMTP_PASS", ""))
        from_addr = notif.get("from", smtp_user)
        to_addr = notif.get("to", "")

        if not to_addr:
            continue

        msg = MIMEMultipart("alternative")
        msg["From"] = from_addr
        msg["To"] = to_addr
        msg["Subject"] = subject
        msg.attach(MIMEText(report, "plain"))

        # Simple markdown-to-html: bold, headers, lists
        html = report
        html = re.sub(r"^# (.+)$", r"<h1>\1</h1>", html, flags=re.MULTILINE)
        html = re.sub(r"^## (.+)$", r"<h2>\1</h2>", html, flags=re.MULTILINE)
        html = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", html)
        html = re.sub(r"_(.+?)_", r"<em>\1</em>", html)
        html = html.replace("\n", "<br>\n")
        html = f'<div style="font-family:sans-serif;max-width:700px;margin:0 auto">{html}</div>'
        msg.attach(MIMEText(html, "html"))

        try:
            server = smtplib.SMTP(smtp_host, smtp_port)
            server.starttls()
            if smtp_user and smtp_pass:
                server.login(smtp_user, smtp_pass)
            server.sendmail(from_addr, [to_addr], msg.as_string())
            server.quit()
            print(f"  Email sent to {to_addr}")
        except Exception as e:
            print(f"  Email failed: {e}", file=sys.stderr)


def write_file(report: str, config: dict) -> None:
    """Write report to file notification targets."""
    for notif in config.get("notifications", []):
        if notif.get("type") != "file":
            continue
        path = notif.get("path", "/tmp/backlog-briefing.md")
        with open(path, "w") as f:
            f.write(report)
        print(f"  Written to {path}")


def notify(report: str, subject: str, config: dict) -> None:
    """Send report to all configured notification channels."""
    write_file(report, config)
    send_email(report, subject, config)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Backlog Surfacing Agent")
    parser.add_argument(
        "mode",
        choices=["morning", "afternoon", "weekly", "monthly"],
        help="Report type to generate",
    )
    parser.add_argument("--config", "-c", help="Path to config.yml")
    parser.add_argument("--dry-run", action="store_true", help="Print to stdout only")
    args = parser.parse_args()

    config = load_config(args.config)
    print(f"Scanning backlogs...")
    tasks = scan_backlogs(config)
    print(f"Found {len(tasks)} tasks across all projects")

    if args.mode == "morning":
        report = generate_morning_briefing(tasks, config)
        subject = f"Backlog Briefing — {datetime.now().strftime('%A, %B %d')}"
    elif args.mode == "afternoon":
        report = generate_morning_briefing(tasks, config)
        subject = f"Afternoon Check-in — {datetime.now().strftime('%A, %B %d')}"
    elif args.mode == "weekly":
        report = generate_weekly_review(tasks, config)
        subject = f"Weekly Review — {datetime.now().strftime('%B %d, %Y')}"
    elif args.mode == "monthly":
        report = generate_monthly_audit(tasks, config)
        subject = f"Monthly Audit — {datetime.now().strftime('%B %Y')}"

    if args.dry_run:
        print()
        print(report)
    else:
        print()
        print(report)
        notify(report, subject, config)


if __name__ == "__main__":
    main()
