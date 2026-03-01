#!/usr/bin/env python3
"""List Claude Code sessions with metadata for FZF picker.

Usage:
    claude-session-list.py [--project DIR] [--detail PROJECT_DIR SESSION_ID]

Modes:
    list (default)  - Tab-delimited session list for FZF consumption
    --detail        - Formatted detail view for FZF preview pane
"""

import json, os, re, sys, time
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"
MAX_SCAN_LINES = 30
# Strip XML/HTML-like tags and system noise from display text
TAG_RE = re.compile(r"<[^>]+>")


def parse_session(filepath):
    """Extract metadata from a session JSONL file."""
    session_id = Path(filepath).stem
    project_dir = Path(filepath).parent.name
    slug = None
    cwd = None
    git_branch = None
    first_user_msg = None

    try:
        mtime = os.path.getmtime(filepath)
    except OSError:
        return None

    try:
        with open(filepath, "r") as f:
            for i, line in enumerate(f):
                if i >= MAX_SCAN_LINES:
                    break
                try:
                    obj = json.loads(line)
                except (json.JSONDecodeError, UnicodeDecodeError):
                    continue

                if not slug and obj.get("slug"):
                    slug = obj["slug"]
                if not cwd and obj.get("cwd"):
                    cwd = obj["cwd"]
                if not git_branch and obj.get("gitBranch"):
                    git_branch = obj["gitBranch"]
                if not first_user_msg and obj.get("type") == "user":
                    content = obj.get("message", {}).get("content", "")
                    if isinstance(content, str) and content.strip():
                        cleaned = TAG_RE.sub("", content).strip()
                        if cleaned:
                            first_user_msg = cleaned[:120].replace("\n", " ").replace("\t", " ")

                if slug and cwd and git_branch and first_user_msg:
                    break
    except (IOError, PermissionError):
        return None

    return {
        "id": session_id,
        "project_dir": project_dir,
        "slug": slug or session_id[:16],
        "cwd": cwd or "?",
        "branch": git_branch or "?",
        "msg": first_user_msg or "(empty session)",
        "mtime": mtime,
    }


def format_age(mtime):
    """Format mtime as human-readable relative age."""
    diff = time.time() - mtime
    if diff < 60:
        return f"{int(diff)}s ago"
    elif diff < 3600:
        return f"{int(diff / 60)}m ago"
    elif diff < 86400:
        return f"{int(diff / 3600)}h ago"
    elif diff < 604800:
        return f"{int(diff / 86400)}d ago"
    else:
        return f"{int(diff / 604800)}w ago"


def list_sessions(project_filter=None):
    """List all sessions, optionally filtered to a project dir."""
    if not PROJECTS_DIR.exists():
        return

    seen_ids = set()
    sessions = []

    for project_dir in PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue
        if project_filter and project_dir.name != project_filter:
            continue

        for session_file in project_dir.glob("*.jsonl"):
            if session_file.is_symlink():
                # Follow symlink but deduplicate
                resolved = session_file.resolve()
                if str(resolved) in seen_ids:
                    continue
                seen_ids.add(str(resolved))

            info = parse_session(str(session_file))
            if info:
                sessions.append(info)

    # Sort by mtime, newest first
    sessions.sort(key=lambda s: s["mtime"], reverse=True)

    for s in sessions:
        age = format_age(s["mtime"])
        project = os.path.basename(s["cwd"]) if s["cwd"] != "?" else "?"
        # Tab-delimited: id \t project_dir \t display (padded columns)
        msg = s["msg"][:50] if len(s["msg"]) > 50 else s["msg"]
        display = f"{s['slug']:<20s}  {age:<8s}  {s['branch']:<25s}  {project:<20s}  {msg}"
        print(f"{s['id']}\t{s['project_dir']}\t{display}")


def show_detail(project_dir_name, session_id):
    """Show detailed session info for FZF preview."""
    session_file = PROJECTS_DIR / project_dir_name / f"{session_id}.jsonl"
    if not session_file.exists():
        print(f"Session file not found: {session_file}")
        return

    info = parse_session(str(session_file))
    if not info:
        print("Could not parse session")
        return

    age = format_age(info["mtime"])
    ts = time.strftime("%Y-%m-%d %H:%M", time.localtime(info["mtime"]))

    print(f"Session:  {info['id']}")
    print(f"Slug:     {info['slug']}")
    print(f"Project:  {info['cwd']}")
    print(f"Branch:   {info['branch']}")
    print(f"Active:   {age} ({ts})")
    print(f"─────────────────────────────────────")

    # Show first few user messages with more detail
    try:
        msg_count = 0
        with open(str(session_file), "r") as f:
            for i, line in enumerate(f):
                if i > 200:
                    break
                try:
                    obj = json.loads(line)
                except (json.JSONDecodeError, UnicodeDecodeError):
                    continue
                if obj.get("type") == "user":
                    content = obj.get("message", {}).get("content", "")
                    if isinstance(content, str) and content.strip():
                        cleaned = TAG_RE.sub("", content).strip()
                        if not cleaned:
                            continue
                        msg_count += 1
                        text = cleaned[:300].replace("\n", "\n  ")
                        print(f"\n> {text}")
                        if msg_count >= 5:
                            break
    except (IOError, PermissionError):
        pass


def main():
    args = sys.argv[1:]

    if "--detail" in args:
        idx = args.index("--detail")
        if idx + 2 < len(args):
            show_detail(args[idx + 1], args[idx + 2])
        else:
            print("Usage: --detail PROJECT_DIR SESSION_ID")
        return

    project_filter = None
    if "--project" in args:
        idx = args.index("--project")
        if idx + 1 < len(args):
            project_filter = args[idx + 1]

    list_sessions(project_filter)


if __name__ == "__main__":
    main()
