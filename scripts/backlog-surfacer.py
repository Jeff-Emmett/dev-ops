#!/usr/bin/env python3
"""
Backlog Surfacing Agent — scans all project backlogs and surfaces relevant tasks.

Usage: python3 backlog-surfacer.py [morning|afternoon|weekly|monthly]

Reads YAML frontmatter from */backlog/tasks/*.md files, applies surfacing
rules, and outputs a formatted markdown briefing.
"""

import sys
import re
import os
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from dataclasses import dataclass
from typing import Optional

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False


# ─────────────────────────────────────────────
# DATA STRUCTURES
# ─────────────────────────────────────────────

@dataclass
class Task:
    id: str
    title: str
    status: str
    priority: str
    created_date: Optional[datetime]
    updated_date: Optional[datetime]
    due_date: Optional[datetime]
    labels: list
    assignee: list
    dependencies: list
    project_dir: str
    project_name: str
    file_path: str

    @property
    def effective_date(self) -> Optional[datetime]:
        return self.updated_date or self.created_date

    @property
    def age_days(self) -> Optional[int]:
        d = self.effective_date
        if d is None:
            return None
        return (datetime.now() - d).days

    @property
    def days_until_due(self) -> Optional[int]:
        if self.due_date is None:
            return None
        return (self.due_date - datetime.now()).days


# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────

DEFAULT_CONFIG = {
    "scan_base": "/home/jeffe/Github",
    "briefing_output": "/tmp/backlog-briefing.md",
    "rules": {
        "stale_in_progress_days": 3,
        "stale_todo_days": 30,
        "upcoming_deadline_days": 14,
        "high_priority_always_surface": True,
        "max_tasks_per_section": 20,
    },
    "notifications": {
        "notify_send": True,
        "stdout": True,
        "file": True,
    },
    "excluded_projects": [],
}


def load_config(config_path: str) -> dict:
    config = dict(DEFAULT_CONFIG)
    if not os.path.exists(config_path):
        return config
    if not HAS_YAML:
        return config
    try:
        with open(config_path) as f:
            user = yaml.safe_load(f) or {}
        if "rules" in user:
            config["rules"] = {**config["rules"], **user["rules"]}
            del user["rules"]
        if "notifications" in user:
            config["notifications"] = {**config["notifications"], **user["notifications"]}
            del user["notifications"]
        config.update(user)
    except Exception:
        pass
    return config


# ─────────────────────────────────────────────
# PARSING
# ─────────────────────────────────────────────

def extract_frontmatter(file_path: str) -> Optional[str]:
    """Read only the YAML frontmatter block (between --- delimiters)."""
    try:
        with open(file_path, "r", encoding="utf-8", errors="replace") as f:
            first_line = f.readline().strip()
            if first_line != "---":
                return None
            lines = []
            for line in f:
                if line.strip() == "---":
                    break
                lines.append(line)
            return "".join(lines) if lines else None
    except (OSError, UnicodeDecodeError):
        return None


def parse_frontmatter(fm_text: str) -> dict:
    """Parse YAML frontmatter with custom regex — handles [@claude], quoted dates, etc."""
    result = {}
    lines = fm_text.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^([\w_]+):\s*(.*)", line)
        if m:
            key, val = m.group(1), m.group(2).strip()

            # Inline flow list: [] or [a, b] or [@claude]
            if val.startswith("[") and val.endswith("]"):
                inner = val[1:-1].strip()
                if not inner:
                    result[key] = []
                else:
                    result[key] = [
                        x.strip().strip("'\"")
                        for x in inner.split(",")
                        if x.strip()
                    ]
            # Quoted scalar
            elif (val.startswith("'") and val.endswith("'")) or (
                val.startswith('"') and val.endswith('"')
            ):
                result[key] = val[1:-1]
            # Empty value — check for block list on next lines
            elif val == "":
                items = []
                i += 1
                while i < len(lines) and re.match(r"^[ \t]", lines[i]):
                    item = lines[i].strip()
                    if item.startswith("- "):
                        items.append(item[2:].strip("'\""))
                    i += 1
                if items:
                    result[key] = items
                else:
                    result[key] = ""
                continue
            else:
                result[key] = val.strip("'\"")
        i += 1
    return result


def parse_date(s) -> Optional[datetime]:
    if not s or not isinstance(s, str):
        return None
    s = s.strip("'\" ")
    for fmt in ("%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            continue
    return None


def normalize_priority(p) -> str:
    if not p or not isinstance(p, str):
        return "none"
    p = p.strip().lower()
    if p in ("high", "medium", "low"):
        return p
    return "none"


def ensure_list(v) -> list:
    if isinstance(v, list):
        return v
    if isinstance(v, str) and v:
        return [v]
    return []


# ─────────────────────────────────────────────
# SCANNER
# ─────────────────────────────────────────────

def load_project_names(scan_base: str) -> dict:
    """Read project_name from each backlog/config.yml. Returns {dir_name: display_name}."""
    names = {}
    pattern = os.path.join(scan_base, "*", "backlog", "config.yml")
    import glob
    for cfg_path in glob.glob(pattern):
        dir_name = Path(cfg_path).parent.parent.name
        if HAS_YAML:
            try:
                with open(cfg_path) as f:
                    data = yaml.safe_load(f) or {}
                names[dir_name] = data.get("project_name", dir_name)
            except Exception:
                names[dir_name] = dir_name
        else:
            names[dir_name] = dir_name
    return names


def scan_all_tasks(config: dict) -> list:
    """Glob all task files, parse frontmatter, build Task objects."""
    import glob
    scan_base = config["scan_base"]
    excluded = set(config.get("excluded_projects", []))
    project_names = load_project_names(scan_base)

    pattern = os.path.join(scan_base, "*", "backlog", "tasks", "*.md")
    tasks = []

    for fp in glob.glob(pattern):
        p = Path(fp)
        project_dir = p.parent.parent.parent.name
        if project_dir in excluded:
            continue

        fm_text = extract_frontmatter(fp)
        if fm_text is None:
            continue

        fm = parse_frontmatter(fm_text)
        if not fm.get("title") and not fm.get("id"):
            continue

        tasks.append(Task(
            id=str(fm.get("id", "")),
            title=str(fm.get("title", p.stem)),
            status=str(fm.get("status", "To Do")),
            priority=normalize_priority(fm.get("priority")),
            created_date=parse_date(fm.get("created_date")),
            updated_date=parse_date(fm.get("updated_date")),
            due_date=parse_date(fm.get("due_date")),
            labels=ensure_list(fm.get("labels", [])),
            assignee=ensure_list(fm.get("assignee", [])),
            dependencies=ensure_list(fm.get("dependencies", [])),
            project_dir=project_dir,
            project_name=project_names.get(project_dir, project_dir),
            file_path=fp,
        ))

    return tasks


# ─────────────────────────────────────────────
# SURFACING RULES
# ─────────────────────────────────────────────

def rule_upcoming_deadlines(tasks: list, cfg: dict) -> list:
    """Tasks with due dates within the next N days (not Done), sorted soonest first."""
    threshold = cfg["rules"]["upcoming_deadline_days"]
    cutoff = datetime.now() + timedelta(days=threshold)
    upcoming = [
        t for t in tasks
        if t.due_date is not None
        and t.status != "Done"
        and t.due_date <= cutoff
    ]
    return sorted(upcoming, key=lambda t: t.due_date)


def rule_high_priority_todo(tasks: list, cfg: dict) -> list:
    return [t for t in tasks if t.status == "To Do" and t.priority == "high"]


def rule_stale_in_progress(tasks: list, cfg: dict) -> list:
    threshold = cfg["rules"]["stale_in_progress_days"]
    cutoff = datetime.now() - timedelta(days=threshold)
    stale = [
        t for t in tasks
        if t.status == "In Progress"
        and t.effective_date is not None
        and t.effective_date < cutoff
    ]
    return sorted(stale, key=lambda t: t.effective_date)


def rule_unassigned_high_priority(tasks: list, cfg: dict) -> list:
    return [
        t for t in tasks
        if t.priority == "high"
        and t.status in ("To Do", "In Progress")
        and not t.assignee
    ]


def rule_in_progress_today(tasks: list, cfg: dict) -> list:
    today = datetime.now().date()
    return [
        t for t in tasks
        if t.status == "In Progress"
        and t.effective_date is not None
        and t.effective_date.date() == today
    ]


def rule_completed_this_week(tasks: list, cfg: dict) -> list:
    week_ago = datetime.now() - timedelta(days=7)
    return [
        t for t in tasks
        if t.status == "Done"
        and t.effective_date is not None
        and t.effective_date >= week_ago
    ]


def rule_no_movement_this_week(tasks: list, cfg: dict) -> list:
    week_ago = datetime.now() - timedelta(days=7)
    return [
        t for t in tasks
        if t.status == "In Progress"
        and t.effective_date is not None
        and t.effective_date < week_ago
    ]


def rule_stale_todo(tasks: list, cfg: dict) -> list:
    threshold = cfg["rules"]["stale_todo_days"]
    cutoff = datetime.now() - timedelta(days=threshold)
    stale = [
        t for t in tasks
        if t.status == "To Do"
        and t.created_date is not None
        and t.created_date < cutoff
    ]
    return sorted(stale, key=lambda t: t.created_date)


def rule_inactive_projects(tasks: list, cfg: dict) -> list:
    """Projects where no task has been updated in the last 30 days."""
    cutoff = datetime.now() - timedelta(days=30)
    project_latest = {}
    for t in tasks:
        d = t.effective_date
        if d and (t.project_dir not in project_latest or d > project_latest[t.project_dir]):
            project_latest[t.project_dir] = d
    return [
        proj for proj, latest in sorted(project_latest.items())
        if latest < cutoff
    ]


# ─────────────────────────────────────────────
# FORMAT HELPERS
# ─────────────────────────────────────────────

def fmt_task(t: Task, show_project: bool = True, show_age: bool = False, show_due: bool = False) -> str:
    parts = ["- "]
    if show_project:
        parts.append(f"**[{t.project_name}]** ")
    parts.append(t.title)
    if t.priority in ("high", "medium"):
        parts.append(f" `{t.priority}`")
    if show_due and t.due_date is not None:
        days = t.days_until_due
        if days < 0:
            parts.append(f" — **OVERDUE by {abs(days)}d**")
        elif days == 0:
            parts.append(" — **DUE TODAY**")
        elif days <= 3:
            parts.append(f" — due in {days}d")
        else:
            parts.append(f" — due {t.due_date.strftime('%b %d')}")
    if show_age and t.age_days is not None:
        parts.append(f" — {t.age_days}d old")
    return "".join(parts)


def cap_list(items: list, max_items: int) -> tuple:
    """Returns (capped_items, overflow_count)."""
    if len(items) <= max_items:
        return items, 0
    return items[:max_items], len(items) - max_items


def group_by_project(tasks: list) -> dict:
    """Group tasks into {project_name: [tasks]} preserving order within groups."""
    groups = {}
    for t in tasks:
        groups.setdefault(t.project_name, []).append(t)
    return groups


def section(title: str, items: list, max_items: int) -> str:
    if not items:
        return ""
    capped, overflow = cap_list(items, max_items)
    lines = [f"\n## {title} ({len(items)})\n"]
    lines.extend(capped)
    if overflow:
        lines.append(f"- *...and {overflow} more*")
    return "\n".join(lines)


def section_by_project(title: str, tasks: list, max_items: int, show_age: bool = False, show_due: bool = False) -> str:
    """Format a section with tasks grouped under project subheadings."""
    if not tasks:
        return ""
    lines = [f"\n## {title} ({len(tasks)})\n"]
    groups = group_by_project(tasks)
    shown = 0
    for proj, proj_tasks in sorted(groups.items(), key=lambda x: -len(x[1])):
        if shown >= max_items:
            remaining = len(tasks) - shown
            lines.append(f"\n*...and {remaining} more across other projects*")
            break
        lines.append(f"\n### {proj}\n")
        for t in proj_tasks:
            if shown >= max_items:
                remaining = len(tasks) - shown
                lines.append(f"- *...and {remaining} more*")
                break
            lines.append(fmt_task(t, show_project=False, show_age=show_age, show_due=show_due))
            shown += 1
    return "\n".join(lines)


# ─────────────────────────────────────────────
# BRIEFING BUILDERS
# ─────────────────────────────────────────────

def stats_header(tasks: list) -> str:
    projects = len({t.project_dir for t in tasks})
    by_status = {}
    for t in tasks:
        by_status[t.status] = by_status.get(t.status, 0) + 1
    parts = [f"{len(tasks)} tasks across {projects} projects"]
    for s in ("In Progress", "To Do", "Done"):
        if s in by_status:
            parts.append(f"{by_status[s]} {s}")
    return " | ".join(parts)


def build_morning_briefing(tasks: list, cfg: dict) -> str:
    now = datetime.now()
    cap = cfg["rules"]["max_tasks_per_section"]

    upcoming = rule_upcoming_deadlines(tasks, cfg)
    high_pri = rule_high_priority_todo(tasks, cfg)
    stale_ip = rule_stale_in_progress(tasks, cfg)
    unassigned = rule_unassigned_high_priority(tasks, cfg)

    lines = [
        "# Backlog Morning Briefing",
        f"*{now.strftime('%A %B %d, %Y %H:%M')} | {stats_header(tasks)}*",
    ]

    # Upcoming deadlines at the very top
    lines.append(section_by_project(
        "Upcoming Deadlines",
        upcoming,
        cap,
        show_due=True,
    ))

    lines.append(section_by_project(
        "High Priority — To Do",
        high_pri,
        cap,
    ))

    lines.append(section_by_project(
        "Stale In Progress — >{}d".format(cfg["rules"]["stale_in_progress_days"]),
        stale_ip,
        cap,
        show_age=True,
    ))

    lines.append(section_by_project(
        "Unassigned High Priority",
        unassigned,
        cap,
    ))

    if not upcoming and not high_pri and not stale_ip and not unassigned:
        lines.append("\nAll clear — nothing urgent to surface today.")

    return "\n".join(filter(None, lines))


def build_afternoon_briefing(tasks: list, cfg: dict) -> str:
    now = datetime.now()
    cap = cfg["rules"]["max_tasks_per_section"]

    upcoming = rule_upcoming_deadlines(tasks, cfg)
    active_today = rule_in_progress_today(tasks, cfg)
    stale_ip = rule_stale_in_progress(tasks, cfg)

    lines = [
        "# Backlog Afternoon Check-in",
        f"*{now.strftime('%A %B %d, %Y %H:%M')}*",
    ]

    # Upcoming deadlines at the top
    lines.append(section_by_project(
        "Upcoming Deadlines",
        upcoming,
        cap,
        show_due=True,
    ))

    lines.append(section_by_project(
        "In Progress Today — still working on these?",
        active_today,
        cap,
    ))

    if stale_ip:
        lines.append(section_by_project(
            "Stale Reminder",
            stale_ip[:5],
            5,
            show_age=True,
        ))

    if not upcoming and not active_today:
        lines.append("\nNo tasks were touched today.")

    return "\n".join(filter(None, lines))


def build_weekly_briefing(tasks: list, cfg: dict) -> str:
    now = datetime.now()
    cap = cfg["rules"]["max_tasks_per_section"]

    upcoming = rule_upcoming_deadlines(tasks, cfg)
    completed = rule_completed_this_week(tasks, cfg)
    stalled = rule_no_movement_this_week(tasks, cfg)
    inactive = rule_inactive_projects(tasks, cfg)

    # Count new tasks this week
    week_ago = now - timedelta(days=7)
    new_this_week = [
        t for t in tasks
        if t.created_date is not None and t.created_date >= week_ago
    ]

    lines = [
        "# Backlog Weekly Review",
        f"*Week ending {now.strftime('%B %d, %Y')} | {stats_header(tasks)}*",
    ]

    # Upcoming deadlines at the top
    lines.append(section_by_project(
        "Upcoming Deadlines",
        upcoming,
        cap,
        show_due=True,
    ))

    lines.append(section_by_project(
        "Completed This Week",
        completed,
        cap,
    ))

    lines.append("\n## Velocity\n")
    lines.append(f"- **{len(completed)}** tasks completed")
    lines.append(f"- **{len(new_this_week)}** tasks created")
    ratio = f"{len(completed)}/{len(new_this_week)}" if new_this_week else f"{len(completed)}/0"
    lines.append(f"- Completion ratio: **{ratio}**")

    lines.append(section_by_project(
        "Stalled — In Progress >7 days",
        stalled,
        cap,
        show_age=True,
    ))

    if inactive:
        lines.append(f"\n## Inactive Projects — no updates in 30 days ({len(inactive)})\n")
        for proj in inactive[:15]:
            lines.append(f"- {proj}")
        if len(inactive) > 15:
            lines.append(f"- *...and {len(inactive) - 15} more*")

    return "\n".join(filter(None, lines))


def build_monthly_briefing(tasks: list, cfg: dict) -> str:
    now = datetime.now()
    cap = cfg["rules"]["max_tasks_per_section"]

    stale_todo = rule_stale_todo(tasks, cfg)
    inactive = rule_inactive_projects(tasks, cfg)

    # Group stale todos by project
    by_project = {}
    for t in stale_todo:
        by_project.setdefault(t.project_name, []).append(t)

    lines = [
        "# Backlog Monthly Audit",
        f"*{now.strftime('%B %Y')} | {stats_header(tasks)}*",
    ]

    # Overall health
    total = len(tasks)
    by_status = {}
    by_pri = {}
    for t in tasks:
        by_status[t.status] = by_status.get(t.status, 0) + 1
        by_pri[t.priority] = by_pri.get(t.priority, 0) + 1

    lines.append("\n## Backlog Health\n")
    for s in ("To Do", "In Progress", "Done"):
        count = by_status.get(s, 0)
        pct = f"{count / total * 100:.0f}%" if total else "0%"
        lines.append(f"- {s}: **{count}** ({pct})")
    lines.append("")
    for p in ("high", "medium", "low", "none"):
        count = by_pri.get(p, 0)
        if count:
            lines.append(f"- Priority {p}: **{count}**")

    if by_project:
        lines.append(f"\n## Stale To Do — >{cfg['rules']['stale_todo_days']}d ({len(stale_todo)} tasks)\n")
        shown = 0
        for proj, proj_tasks in sorted(by_project.items(), key=lambda x: -len(x[1])):
            if shown >= cap:
                remaining = len(stale_todo) - shown
                lines.append(f"\n*...and {remaining} more across other projects*")
                break
            lines.append(f"\n### {proj} ({len(proj_tasks)})\n")
            for t in proj_tasks[:5]:
                lines.append(fmt_task(t, show_project=False, show_age=True))
            if len(proj_tasks) > 5:
                lines.append(f"- *...and {len(proj_tasks) - 5} more*")
            shown += len(proj_tasks)

    if inactive:
        lines.append(f"\n## Inactive Projects ({len(inactive)})\n")
        for proj in inactive[:20]:
            lines.append(f"- {proj}")
        if len(inactive) > 20:
            lines.append(f"- *...and {len(inactive) - 20} more*")

    return "\n".join(filter(None, lines))


# ─────────────────────────────────────────────
# OUTPUT / NOTIFICATIONS
# ─────────────────────────────────────────────

def write_briefing_file(content: str, path: str) -> None:
    with open(path, "w") as f:
        f.write(content + "\n")


def send_desktop_notification(mode: str, task_count: int) -> None:
    summary = {
        "morning": f"Morning Briefing: {task_count} items to review",
        "afternoon": f"Afternoon Check-in: {task_count} active tasks",
        "weekly": "Weekly Review ready",
        "monthly": f"Monthly Audit: {task_count} stale tasks",
    }.get(mode, f"Backlog: {task_count} items")
    try:
        subprocess.run(
            ["notify-send", "-a", "Backlog", "Backlog Surfacer", summary],
            timeout=5,
            capture_output=True,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass


def extract_surface_count(mode: str, tasks: list, cfg: dict) -> int:
    """Count of items surfaced for the notification summary."""
    if mode == "morning":
        return (len(rule_upcoming_deadlines(tasks, cfg))
                + len(rule_high_priority_todo(tasks, cfg))
                + len(rule_stale_in_progress(tasks, cfg)))
    elif mode == "afternoon":
        return (len(rule_upcoming_deadlines(tasks, cfg))
                + len(rule_in_progress_today(tasks, cfg)))
    elif mode == "weekly":
        return (len(rule_upcoming_deadlines(tasks, cfg))
                + len(rule_completed_this_week(tasks, cfg)))
    elif mode == "monthly":
        return len(rule_stale_todo(tasks, cfg))
    return 0


# ─────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────

MODES = ["morning", "afternoon", "weekly", "monthly"]

MODE_BUILDERS = {
    "morning": build_morning_briefing,
    "afternoon": build_afternoon_briefing,
    "weekly": build_weekly_briefing,
    "monthly": build_monthly_briefing,
}


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "morning"
    if mode not in MODES:
        print(f"Usage: backlog-surfacer.py [{' | '.join(MODES)}]", file=sys.stderr)
        sys.exit(1)

    config_path = str(Path(__file__).parent / "backlog-surfacer.yml")
    config = load_config(config_path)

    tasks = scan_all_tasks(config)
    content = MODE_BUILDERS[mode](tasks, config)

    if config["notifications"]["file"]:
        output_path = config["briefing_output"]
        write_briefing_file(content, output_path)
        print(f"Briefing written to {output_path}", file=sys.stderr)

    if config["notifications"]["stdout"]:
        print(content)

    if config["notifications"]["notify_send"]:
        count = extract_surface_count(mode, tasks, config)
        send_desktop_notification(mode, count)


if __name__ == "__main__":
    main()
