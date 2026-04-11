"""
Markdown Writer Utilities

Write markdown files to Obsidian vault with YAML frontmatter.
"""

import os
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List, Optional
import uuid

from .config import SESSIONS_DIR, MEMORIES_DIR, AUDIT_DIR, SYNTHESIS_DIR, MEMORY_TYPES


def slugify(text: str, max_length: int = 50) -> str:
    """
    Convert text to a URL-safe slug.

    Args:
        text: Text to slugify
        max_length: Maximum slug length

    Returns:
        Slugified string
    """
    # Convert to lowercase
    slug = text.lower()
    # Replace spaces and special chars with hyphens
    slug = re.sub(r"[^a-z0-9]+", "-", slug)
    # Remove leading/trailing hyphens
    slug = slug.strip("-")
    # Truncate
    return slug[:max_length]


def generate_short_id() -> str:
    """Generate a short unique ID (8 chars)."""
    return uuid.uuid4().hex[:8]


def format_frontmatter(data: Dict[str, Any]) -> str:
    """
    Format a dict as YAML frontmatter.

    Args:
        data: Dictionary to format

    Returns:
        YAML frontmatter string with --- delimiters
    """
    lines = ["---"]

    for key, value in data.items():
        if value is None:
            continue
        elif isinstance(value, bool):
            lines.append(f"{key}: {str(value).lower()}")
        elif isinstance(value, list):
            if value:
                lines.append(f"{key}:")
                for item in value:
                    lines.append(f'  - "{item}"')
            else:
                lines.append(f"{key}: []")
        elif isinstance(value, (int, float)):
            lines.append(f"{key}: {value}")
        else:
            # Escape quotes in strings
            str_val = str(value).replace('"', '\\"')
            lines.append(f'{key}: "{str_val}"')

    lines.append("---")
    return "\n".join(lines)


def update_frontmatter(file_path: Path, updates: Dict[str, Any]) -> bool:
    """
    Update frontmatter in an existing file.

    Args:
        file_path: Path to the file
        updates: Dict of frontmatter fields to update

    Returns:
        True if successful
    """
    try:
        content = file_path.read_text()

        if content.startswith("---"):
            end = content.find("---", 3)
            if end > 0:
                frontmatter_text = content[3:end].strip()
                body = content[end + 3 :].strip()
            else:
                return False
        else:
            return False

        # Parse existing frontmatter
        frontmatter = {}
        for line in frontmatter_text.split("\n"):
            if ":" in line:
                key, value = line.split(":", 1)
                frontmatter[key.strip()] = value.strip().strip("\"'")

        # Apply updates
        frontmatter.update(updates)

        # Write back
        new_content = format_frontmatter(frontmatter) + "\n\n" + body
        file_path.write_text(new_content)
        return True
    except Exception:
        return False


def write_session(
    session_id: str,
    created: datetime,
    work_type: str,
    first_message: str,
    last_message: str,
    user_messages: List[str],
    assistant_messages: List[str],
    tool_calls: List[Dict[str, Any]],
    files_touched: List[str],
    token_estimate: int,
) -> Optional[Path]:
    """
    Write a session to the Obsidian vault.

    Args:
        session_id: Claude Code session ID
        created: Session creation time
        work_type: Classified work type
        first_message: First user message
        last_message: Last user message
        user_messages: All user messages
        assistant_messages: All assistant messages
        tool_calls: List of tool calls made
        files_touched: List of files touched

    Returns:
        Path to created file or None if failed
    """
    try:
        SESSIONS_DIR.mkdir(parents=True, exist_ok=True)

        # Generate filename
        date_str = created.strftime("%Y-%m-%d")
        short_id = session_id[:8] if len(session_id) >= 8 else generate_short_id()
        filename = f"{date_str}-{short_id}.md"
        file_path = SESSIONS_DIR / filename

        # Build frontmatter
        frontmatter = {
            "type": "claude-session",
            "session_id": session_id,
            "created": created.isoformat(),
            "work_type": work_type,
            "token_estimate": token_estimate,
            "memories_extracted": False,
            "files_touched": files_touched[:20],  # Limit
            "tags": ["claude-session", f"work/{work_type}"],
        }

        # Build body
        body_parts = [f"# Session: {date_str}"]

        # Summary
        body_parts.append("\n## Summary")
        body_parts.append(f"- **Work Type:** {work_type}")
        body_parts.append(f"- **Messages:** {len(user_messages)} user, {len(assistant_messages)} assistant")
        body_parts.append(f"- **Tool Calls:** {len(tool_calls)}")
        body_parts.append(f"- **Token Estimate:** {token_estimate:,}")

        # First/Last message
        body_parts.append("\n## First Message")
        body_parts.append(f"> {first_message[:500]}..." if len(first_message) > 500 else f"> {first_message}")

        if last_message and last_message != first_message:
            body_parts.append("\n## Last Message")
            body_parts.append(f"> {last_message[:500]}..." if len(last_message) > 500 else f"> {last_message}")

        # Files touched
        if files_touched:
            body_parts.append("\n## Files Touched")
            for f in files_touched[:20]:
                body_parts.append(f"- `{f}`")

        # Tool calls summary
        if tool_calls:
            body_parts.append("\n## Tool Calls")
            body_parts.append("| Tool | Count |")
            body_parts.append("|------|-------|")
            tool_counts = {}
            for tc in tool_calls:
                tool_name = tc.get("name", "unknown")
                tool_counts[tool_name] = tool_counts.get(tool_name, 0) + 1
            for tool, count in sorted(tool_counts.items(), key=lambda x: -x[1]):
                body_parts.append(f"| {tool} | {count} |")

        # Write file
        content = format_frontmatter(frontmatter) + "\n\n" + "\n".join(body_parts)
        file_path.write_text(content)

        return file_path
    except Exception as e:
        print(f"Error writing session: {e}")
        return None


def write_memory(
    memory_type: str,
    title: str,
    summary: str,
    reasoning: str,
    confidence: float,
    entities: List[str],
    context: str,
    source_session: Optional[str] = None,
    category: str = "technical",
) -> Optional[Path]:
    """
    Write a memory to the Obsidian vault.

    Args:
        memory_type: Type of memory (correction, decision, etc.)
        title: Memory title
        summary: Brief summary
        reasoning: Why this is worth remembering
        confidence: Confidence score (0-1)
        entities: Related entities
        context: Original context snippet
        source_session: Path to source session file
        category: Memory category

    Returns:
        Path to created file or None if failed
    """
    try:
        # Ensure type directory exists
        type_dir = MEMORIES_DIR / memory_type
        type_dir.mkdir(parents=True, exist_ok=True)

        # Generate filename
        now = datetime.now()
        date_str = now.strftime("%Y-%m-%d")
        slug = slugify(title)
        short_id = generate_short_id()
        filename = f"{date_str}-{slug}-{short_id}.md"
        file_path = type_dir / filename

        # Get type info
        type_info = MEMORY_TYPES.get(memory_type, {})
        emoji = type_info.get("emoji", "*")

        # Build frontmatter
        frontmatter = {
            "type": memory_type,
            "category": category,
            "confidence": round(confidence, 2),
            "formed": now.isoformat(),
            "source_session": source_session or "",
            "entities": entities,
            "tags": ["claude-memory", f"memory/{memory_type}"],
        }

        # Build body
        body_parts = [f"# {emoji} {title}"]

        body_parts.append("\n## Summary")
        body_parts.append(summary)

        if reasoning:
            body_parts.append("\n## Why This Matters")
            body_parts.append(reasoning)

        if context:
            body_parts.append("\n## Original Context")
            body_parts.append(f"> {context}")

        if entities:
            body_parts.append("\n## Related Entities")
            for entity in entities:
                body_parts.append(f"- {entity}")

        if source_session:
            body_parts.append("\n## Source")
            # Create Obsidian link
            session_link = source_session.replace(".md", "").replace("Claude/", "")
            body_parts.append(f"[[{session_link}|Session]]")

        # Write file
        content = format_frontmatter(frontmatter) + "\n\n" + "\n".join(body_parts)
        file_path.write_text(content)

        return file_path
    except Exception as e:
        print(f"Error writing memory: {e}")
        return None


def write_audit(
    tool_name: str,
    session_id: str,
    action_details: Dict[str, Any],
    success: bool = True,
    duration_ms: Optional[int] = None,
) -> Optional[Path]:
    """
    Write an audit trail entry to the Obsidian vault.

    Args:
        tool_name: Name of the tool used
        session_id: Claude Code session ID
        action_details: Details of the action
        success: Whether action succeeded
        duration_ms: Action duration in milliseconds

    Returns:
        Path to created file or None if failed
    """
    try:
        # Create daily directory
        now = datetime.now()
        date_str = now.strftime("%Y-%m-%d")
        time_str = now.strftime("%H-%M-%S")
        daily_dir = AUDIT_DIR / date_str
        daily_dir.mkdir(parents=True, exist_ok=True)

        # Generate filename
        filename = f"{time_str}-{tool_name.lower()}.md"
        file_path = daily_dir / filename

        # Build frontmatter
        frontmatter = {
            "type": "claude-audit",
            "timestamp": now.isoformat(),
            "tool": tool_name,
            "session": session_id[:8] if len(session_id) >= 8 else session_id,
            "success": success,
            "duration_ms": duration_ms,
            "tags": ["claude-audit", f"tool/{tool_name.lower()}"],
        }

        # Build body
        body_parts = [f"# {tool_name}"]

        # Extract meaningful details
        file_path_detail = action_details.get("file_path") or action_details.get("path") or ""
        command = action_details.get("command", "")

        if file_path_detail:
            body_parts[0] = f"# {tool_name}: {Path(file_path_detail).name}"
            body_parts.append("\n## Details")
            body_parts.append(f"- **File:** `{file_path_detail}`")
        elif command:
            body_parts.append("\n## Command")
            body_parts.append(f"```bash\n{command[:500]}\n```")

        body_parts.append(f"- **Status:** {'Success' if success else 'Failed'}")
        if duration_ms:
            body_parts.append(f"- **Duration:** {duration_ms}ms")

        # Session link
        body_parts.append("\n## Session")
        session_short = session_id[:8] if len(session_id) >= 8 else session_id
        body_parts.append(f"Session: `{session_short}`")

        # Write file
        content = format_frontmatter(frontmatter) + "\n\n" + "\n".join(body_parts)
        file_path.write_text(content)

        return file_path
    except Exception as e:
        print(f"Error writing audit: {e}")
        return None


def write_synthesis(
    week: str,
    sessions_count: int,
    memories_count: int,
    work_distribution: Dict[str, int],
    corrections: List[Dict[str, Any]],
    patterns: List[Dict[str, Any]],
    recommendations: List[str],
) -> Optional[Path]:
    """
    Write a weekly synthesis to the Obsidian vault.

    Args:
        week: ISO week string (e.g., '2025-W02')
        sessions_count: Number of sessions this week
        memories_count: Number of memories formed
        work_distribution: Dict of work_type -> count
        corrections: List of key corrections
        patterns: List of detected patterns
        recommendations: List of SOP recommendations

    Returns:
        Path to created file or None if failed
    """
    try:
        SYNTHESIS_DIR.mkdir(parents=True, exist_ok=True)

        # Generate filename
        filename = f"{week}.md"
        file_path = SYNTHESIS_DIR / filename

        now = datetime.now()

        # Build frontmatter
        frontmatter = {
            "type": "claude-synthesis",
            "period": "weekly",
            "week": week,
            "generated": now.isoformat(),
            "sessions": sessions_count,
            "memories": memories_count,
            "tags": ["claude-synthesis", "weekly"],
        }

        # Build body
        body_parts = [f"# Weekly Synthesis: {week}"]

        body_parts.append("\n## Overview")
        body_parts.append(f"- **Sessions:** {sessions_count}")
        body_parts.append(f"- **Memories Formed:** {memories_count}")

        if work_distribution:
            body_parts.append("\n## Work Distribution")
            body_parts.append("| Work Type | Sessions |")
            body_parts.append("|-----------|----------|")
            for work_type, count in sorted(work_distribution.items(), key=lambda x: -x[1]):
                body_parts.append(f"| {work_type} | {count} |")

        if corrections:
            body_parts.append("\n## Key Corrections")
            for c in corrections[:10]:
                conf = c.get("confidence", 0)
                body_parts.append(f"- **{c.get('title', 'Untitled')}** ({conf:.0%})")

        if patterns:
            body_parts.append("\n## Notable Patterns")
            for p in patterns[:10]:
                body_parts.append(f"- {p.get('title', 'Untitled')}")

        if recommendations:
            body_parts.append("\n## SOP Recommendations")
            for i, rec in enumerate(recommendations[:10], 1):
                body_parts.append(f"{i}. {rec}")

        # Write file
        content = format_frontmatter(frontmatter) + "\n\n" + "\n".join(body_parts)
        file_path.write_text(content)

        return file_path
    except Exception as e:
        print(f"Error writing synthesis: {e}")
        return None
