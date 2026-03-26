#!/usr/bin/env python3
"""Extract actionable context from a Claude Code session JSONL file.

Usage:
    python3 extract_context.py <session_file> [--list] [--search QUERY]

Outputs structured sections:
    - SESSION_STATUS: completed | interrupted | error_cascade | abandoned
    - COMPACT_SUMMARY: last compaction summary (highest-signal context)
    - RECENT_MESSAGES: last 20 meaningful user/assistant messages
    - ERRORS: tool errors encountered in the session
    - TOOL_STATS: most-used tools and file paths
"""

import json
import sys
import os
from collections import Counter
from datetime import datetime


def classify_session_end(entries):
    """Determine how a session ended based on final entries."""
    if not entries:
        return "unknown"

    last_entries = entries[-10:]
    last_types = [e.get("type", "") for e in last_entries]
    last_content = " ".join(str(e.get("message", {}).get("content", ""))[:200] for e in last_entries).lower()

    # Completed: last assistant message contains completion language
    completion_signals = [
        "complete",
        "done",
        "finished",
        "all set",
        "wrapped up",
        "committed",
        "merged",
        "TICKET_TASK_COMPLETE",
    ]
    if any(s in last_content for s in completion_signals):
        return "completed"

    # Error cascade: multiple consecutive tool errors
    error_count = sum(
        1 for e in last_entries if e.get("type") == "tool_result" and "error" in str(e.get("content", "")).lower()
    )
    if error_count >= 3:
        return "error_cascade"

    # Interrupted: last message is from user (they were still talking)
    for e in reversed(last_entries):
        if e.get("type") == "user":
            return "interrupted"
        if e.get("type") == "assistant":
            break

    # Abandoned: session just stopped (no clear ending)
    return "abandoned"


def extract_compact_summary(entries):
    """Find the last compaction summary."""
    last_compact = None
    for entry in entries:
        if entry.get("type") == "summary":
            last_compact = entry
    if not last_compact:
        return None

    msg = last_compact.get(
        "summary",
        last_compact.get("message", {}).get("content", ""),
    )
    if isinstance(msg, list):
        texts = [c.get("text", "") for c in msg if isinstance(c, dict) and c.get("type") == "text"]
        msg = "\n".join(texts)
    return str(msg)[:4000]


def extract_recent_messages(entries, count=20):
    """Get last N meaningful user/assistant messages."""
    messages = []
    for entry in entries:
        if entry.get("type") not in ("user", "assistant"):
            continue
        msg = entry.get("message", {})
        role = msg.get("role", entry.get("type", ""))
        content = msg.get("content", "")
        if isinstance(content, list):
            texts = [c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text"]
            content = "\n".join(texts)
        content = str(content).strip()
        if content and "<system-reminder>" not in content and "<task-notification>" not in content:
            messages.append((role, content[:500]))
    return messages[-count:]


def extract_errors(entries, count=10):
    """Find tool errors in the session."""
    errors = []
    for entry in entries:
        if entry.get("type") == "tool_result":
            content = str(entry.get("content", ""))
            if "error" in content.lower():
                errors.append(content[:300])
    return errors[-count:]


def extract_tool_stats(entries):
    """Count tool usage and file paths touched."""
    tools = Counter()
    files = Counter()
    for entry in entries:
        if entry.get("type") == "tool_use":
            tool_name = entry.get("name", entry.get("tool", "unknown"))
            tools[tool_name] += 1
            # Extract file paths from common tool params
            params = entry.get("input", entry.get("params", {}))
            if isinstance(params, dict):
                for key in ("file_path", "path", "file"):
                    if key in params:
                        files[params[key]] += 1
    return tools.most_common(10), files.most_common(15)


def load_session(path):
    """Load and parse JSONL session file."""
    entries = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    return entries


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 extract_context.py <session_file>", file=sys.stderr)
        sys.exit(1)

    session_file = sys.argv[1]
    if not os.path.exists(session_file):
        print(f"File not found: {session_file}", file=sys.stderr)
        sys.exit(1)

    entries = load_session(session_file)
    if not entries:
        print("Empty session file", file=sys.stderr)
        sys.exit(1)

    # Session metadata
    mtime = os.path.getmtime(session_file)
    last_modified = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M")
    size_mb = os.path.getsize(session_file) / (1024 * 1024)

    # Extract all sections
    status = classify_session_end(entries)
    summary = extract_compact_summary(entries)
    messages = extract_recent_messages(entries)
    errors = extract_errors(entries)
    top_tools, top_files = extract_tool_stats(entries)

    # Output
    print(f"=== SESSION: {os.path.basename(session_file)} ===")
    print(f"Last modified: {last_modified}")
    print(f"Size: {size_mb:.1f} MB")
    print(f"Entries: {len(entries)}")
    print(f"Status: {status.upper()}")
    print()

    # Strategy guidance based on status
    strategies = {
        "completed": "Session ended normally. Check if follow-up work was mentioned.",
        "interrupted": "User was mid-conversation. Resume from their last message.",
        "error_cascade": "Session hit repeated errors. Check errors below before retrying the same approach.",
        "abandoned": "Session stopped without conclusion. Check recent messages for intent.",
    }
    print(f"Strategy: {strategies.get(status, 'Unknown status')}")
    print()

    if summary:
        print("=== COMPACT SUMMARY ===")
        print(summary)
        print()

    if messages:
        print("=== RECENT MESSAGES ===")
        for role, content in messages:
            print(f"\n[{role.upper()}]: {content}")
        print()

    if errors:
        print("=== ERRORS ===")
        for e in errors:
            print(f"- {e}")
        print()

    if top_tools:
        print("=== TOP TOOLS ===")
        for tool, count in top_tools:
            print(f"  {tool}: {count}")

    if top_files:
        print("\n=== FILES TOUCHED ===")
        for fpath, count in top_files:
            print(f"  {fpath} ({count}x)")


if __name__ == "__main__":
    main()
