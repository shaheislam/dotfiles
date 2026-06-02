#!/usr/bin/env python3
"""
SessionEnd Hook - Extract memories from completed Claude Code session.

This hook triggers when a Claude Code session ends and:
1. Parses the session transcript
2. Detects memory triggers (corrections, enthusiasm, recovery patterns)
3. Calls Claude to extract memories
4. Writes memories directly to Obsidian vault

Hook Input (stdin JSON):
{
  "hook_type": "SessionEnd",
  "session_id": "abc123",
  "cwd": "/path/to/project",
  "transcript_path": "/path/to/transcript.txt"
}

Hook Output (stdout JSON):
{
  "continue": true
}
"""

import json
import subprocess
import sys
import re
import os
import time
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

# Add lib to path
sys.path.insert(0, str(Path(__file__).parent))

from lib.config import (
    CLAUDE_PROJECTS_DIR,
    SESSIONS_DIR,
    MEMORIES_DIR,
    TRIGGER_PATTERNS,
    FAILURE_PATTERNS,
    SUCCESS_PATTERNS,
    MAX_MEMORIES_PER_SESSION,
    MAX_TRANSCRIPT_LENGTH,
    MEMORY_TYPES,
)
from lib.markdown_writer import write_session, write_memory, update_frontmatter
from lib.ripgrep_search import find_session_by_id


LOCK_DIR = Path(os.environ.get("JFDI_SESSION_EXTRACT_LOCK_DIR", "/tmp/jfdi-session-extract"))
LOCK_TTL_SECONDS = int(os.environ.get("JFDI_SESSION_EXTRACT_LOCK_TTL", "600"))


def extraction_disabled() -> bool:
    """Return true when extraction is explicitly disabled for this process tree."""
    return os.environ.get("JFDI_SESSION_EXTRACT_DISABLE", "").lower() in {"1", "true", "yes"}


def is_extraction_session(session: Dict[str, Any]) -> bool:
    """Avoid extracting memories from the extractor's own Claude --print sessions."""
    first_message = session.get("first_message", "").lstrip()
    return first_message.startswith("# Memory Extraction Task")


def acquire_session_lock(session_id: str) -> Optional[Path]:
    """Acquire a best-effort per-session lock to prevent Stop/SessionEnd fan-out."""
    safe_session_id = re.sub(r"[^A-Za-z0-9_.-]", "_", session_id)
    LOCK_DIR.mkdir(parents=True, exist_ok=True)
    lock_path = LOCK_DIR / f"{safe_session_id}.lock"

    try:
        fd = os.open(str(lock_path), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(f"{os.getpid()}\n{int(time.time())}\n")
        return lock_path
    except FileExistsError:
        try:
            age = time.time() - lock_path.stat().st_mtime
            if age > LOCK_TTL_SECONDS:
                lock_path.unlink()
                return acquire_session_lock(session_id)
        except OSError:
            return None
        return None


def release_session_lock(lock_path: Optional[Path]) -> None:
    if not lock_path:
        return
    try:
        lock_path.unlink()
    except OSError:
        pass


def detect_triggers(messages: List[str]) -> List[Dict[str, Any]]:
    """
    Detect memory extraction triggers in user messages.

    Returns list of detected triggers with type, priority, and context.
    """
    triggers = []

    for i, message in enumerate(messages):
        for trigger_name, config in TRIGGER_PATTERNS.items():
            for pattern in config["patterns"]:
                match = re.search(pattern, message, re.IGNORECASE)
                if match:
                    triggers.append(
                        {
                            "type": trigger_name,
                            "message_index": i,
                            "message": message[:200],
                            "match": match.group(0),
                            "priority": config["priority"],
                            "suggested_type": config["memory_type"],
                        }
                    )
                    break  # One match per trigger type per message

    # Detect recovery patterns (fail -> succeed sequence)
    triggers.extend(detect_recovery_patterns(messages))

    return triggers


def detect_recovery_patterns(messages: List[str]) -> List[Dict[str, Any]]:
    """Detect recovery patterns (multiple failures followed by success)."""
    triggers = []
    failure_count = 0
    last_failure_idx = -1

    for i, message in enumerate(messages):
        is_failure = any(re.search(p, message, re.IGNORECASE) for p in FAILURE_PATTERNS)
        is_success = any(re.search(p, message, re.IGNORECASE) for p in SUCCESS_PATTERNS)

        if is_failure:
            failure_count += 1
            last_failure_idx = i
        elif is_success and failure_count >= 1 and i - last_failure_idx <= 3:
            triggers.append(
                {
                    "type": "recovery_pattern",
                    "message_index": i,
                    "message": message[:200],
                    "match": f"Recovery after {failure_count} attempt(s)",
                    "priority": "high",
                    "suggested_type": "learning",
                }
            )
            failure_count = 0

    return triggers


def parse_session_jsonl(session_id: str) -> Optional[Dict[str, Any]]:
    """
    Find and parse a Claude Code session JSONL file.

    Returns parsed session data or None if not found.
    """
    if not CLAUDE_PROJECTS_DIR.exists():
        return None

    # Search for session file
    for jsonl_file in CLAUDE_PROJECTS_DIR.rglob("*.jsonl"):
        try:
            with open(jsonl_file, "r") as f:
                first_line = f.readline()
                if not first_line:
                    continue

                data = json.loads(first_line)
                if data.get("sessionId") == session_id:
                    # Found the session - parse it
                    f.seek(0)
                    return parse_jsonl_content(f.read(), jsonl_file)
        except Exception:
            continue

    return None


def parse_jsonl_content(content: str, file_path: Path) -> Dict[str, Any]:
    """Parse JSONL session content into structured data."""
    user_messages = []
    assistant_messages = []
    tool_calls = []
    files_touched = set()
    created_at = None
    session_id = None

    for line in content.strip().split("\n"):
        if not line.strip():
            continue

        try:
            data = json.loads(line)

            # Extract session metadata
            if not session_id:
                session_id = data.get("sessionId", "")
            if not created_at and data.get("timestamp"):
                created_at = data["timestamp"]

            # Extract messages
            msg_type = data.get("type", "")

            if msg_type == "user":
                text = data.get("message", {}).get("content", "")
                if isinstance(text, str) and text.strip():
                    user_messages.append(text)

            elif msg_type == "assistant":
                text = data.get("message", {}).get("content", "")
                if isinstance(text, str):
                    assistant_messages.append(text[:500])  # Truncate

            elif msg_type == "tool_use":
                tool_name = data.get("name", "")
                tool_input = data.get("input", {})

                tool_calls.append({"name": tool_name, "input": tool_input})

                # Extract files from tool calls
                if tool_name in ["Read", "Edit", "Write"]:
                    file_path = tool_input.get("file_path", "")
                    if file_path:
                        files_touched.add(file_path)
                elif tool_name == "Glob":
                    pattern = tool_input.get("pattern", "")
                    if pattern:
                        files_touched.add(f"[glob: {pattern}]")

        except json.JSONDecodeError:
            continue

    # Classify work type
    work_type = classify_work_type(user_messages, tool_calls)

    # Estimate tokens
    total_text = " ".join(user_messages + assistant_messages)
    token_estimate = len(total_text) // 4

    return {
        "session_id": session_id or file_path.stem,
        "created_at": created_at or datetime.now().isoformat(),
        "work_type": work_type,
        "user_messages": user_messages,
        "assistant_messages": assistant_messages,
        "tool_calls": tool_calls,
        "files_touched": list(files_touched),
        "token_estimate": token_estimate,
        "first_message": user_messages[0] if user_messages else "",
        "last_message": user_messages[-1] if user_messages else "",
    }


def classify_work_type(messages: List[str], tool_calls: List[Dict]) -> str:
    """Classify the type of work done in the session."""
    text = " ".join(messages).lower()

    patterns = {
        "debugging": ["debug", "fix", "bug", "error", "issue", "problem", "broken"],
        "development": ["implement", "create", "build", "add", "feature", "component"],
        "refactoring": ["refactor", "cleanup", "reorganize", "restructure", "rename"],
        "testing": ["test", "spec", "coverage", "assertion", "expect"],
        "documentation": ["document", "readme", "comment", "explain", "docs"],
        "research": ["research", "explore", "investigate", "find", "search", "understand"],
        "planning": ["plan", "design", "architect", "strategy", "roadmap"],
    }

    for work_type, keywords in patterns.items():
        if any(kw in text for kw in keywords):
            return work_type

    # Check tool usage patterns
    tool_names = [tc["name"] for tc in tool_calls]
    if tool_names.count("Edit") > 3:
        return "development"
    if tool_names.count("Grep") > 3 or tool_names.count("Glob") > 3:
        return "research"

    return "general"


def build_extraction_prompt(session: Dict[str, Any], triggers: List[Dict]) -> str:
    """Build the prompt for Claude to extract memories."""
    # Format transcript
    transcript_parts = []
    user_msgs = session["user_messages"]
    asst_msgs = session["assistant_messages"]

    for i in range(max(len(user_msgs), len(asst_msgs))):
        if i < len(user_msgs):
            transcript_parts.append(f"USER: {user_msgs[i][:1000]}")
        if i < len(asst_msgs):
            transcript_parts.append(f"ASSISTANT: {asst_msgs[i][:500]}")

    transcript = "\n\n---\n\n".join(transcript_parts)
    if len(transcript) > MAX_TRANSCRIPT_LENGTH:
        transcript = transcript[:MAX_TRANSCRIPT_LENGTH] + "\n\n[... truncated ...]"

    # Format triggers section
    triggers_section = ""
    if triggers:
        trigger_lines = []
        for i, t in enumerate(triggers[:10]):
            trigger_lines.append(f'{i + 1}. **{t["type"]}** ({t["priority"]}) - "{t["match"]}"')
        triggers_section = f"""
## Pre-Detected Triggers (HIGH PRIORITY)
{chr(10).join(trigger_lines)}

For each trigger above, extract a relevant memory or explain why it's not memorable.
"""

    # Memory types documentation
    type_docs = "\n".join(
        [f"- **{t}** ({info['priority']}): {info['description']}" for t, info in MEMORY_TYPES.items()]
    )

    return f"""# Memory Extraction Task

Analyze this Claude Code session and extract memories worth remembering.

## Session Info
- **Session ID:** {session["session_id"][:8]}
- **Work Type:** {session["work_type"]}
- **Messages:** {len(session["user_messages"])} user, {len(session["assistant_messages"])} assistant
- **Triggers Detected:** {len(triggers)}
{triggers_section}
## Session Transcript
```
{transcript}
```

## Memory Types
{type_docs}

## Output Format
Respond with ONLY a JSON array of memories:

```json
[
  {{
    "type": "correction|decision|insight|learning|commitment|pattern|workflow",
    "category": "technical|systems|relationship|creative|planning",
    "title": "Brief title (5-10 words)",
    "summary": "1-2 sentence summary",
    "reasoning": "Why this is worth remembering",
    "confidence": 0.5-1.0,
    "entities": ["entity1", "entity2"],
    "context": "Relevant quote from transcript"
  }}
]
```

## Rules
- Extract 0-{MAX_MEMORIES_PER_SESSION} memories maximum
- Quality over quantity
- Corrections require confidence >= 0.7
- Other types require confidence >= 0.5
- If no memories worth extracting, return: []"""


def call_claude_for_extraction(prompt: str) -> List[Dict[str, Any]]:
    """Call Claude CLI to extract memories from the prompt."""
    try:
        env = os.environ.copy()
        env["JFDI_SESSION_EXTRACT_DISABLE"] = "1"

        # Use claude CLI with print mode
        result = subprocess.run(
            ["claude", "--print", "-p", prompt],
            capture_output=True,
            text=True,
            timeout=120,
            env=env,
        )

        if result.returncode != 0:
            return []

        response = result.stdout

        # Parse JSON from response
        json_match = (
            re.search(r"```json\n([\s\S]*?)\n```", response)
            or re.search(r"```\n([\s\S]*?)\n```", response)
            or re.search(r"\[[\s\S]*\]", response)
        )

        if not json_match:
            return []

        json_str = json_match.group(1) if json_match.lastindex else json_match.group(0)
        memories = json.loads(json_str)

        if not isinstance(memories, list):
            return []

        # Validate memories
        valid_memories = []
        for mem in memories:
            if validate_memory(mem):
                valid_memories.append(mem)

        return valid_memories[:MAX_MEMORIES_PER_SESSION]

    except Exception as e:
        print(f"Error calling Claude: {e}", file=sys.stderr)
        return []


def validate_memory(mem: Dict[str, Any]) -> bool:
    """Validate a memory object has required fields and valid values."""
    if not isinstance(mem, dict):
        return False

    # Required fields
    required = ["type", "title", "summary", "confidence"]
    if not all(k in mem for k in required):
        return False

    # Valid type
    if mem["type"] not in MEMORY_TYPES:
        return False

    # Confidence threshold
    confidence = float(mem.get("confidence", 0))
    min_conf = MEMORY_TYPES[mem["type"]]["min_confidence"]
    if confidence < min_conf:
        return False

    return True


def main():
    """Main hook entry point."""
    if extraction_disabled():
        print(json.dumps({"continue": True}))
        return

    # Read hook input from stdin
    try:
        input_data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, Exception):
        print(json.dumps({"continue": True}))
        return

    session_id = input_data.get("session_id", "")

    if not session_id:
        print(json.dumps({"continue": True}))
        return

    lock_path = acquire_session_lock(session_id)
    if not lock_path:
        print(json.dumps({"continue": True}))
        return

    try:
        # Parse the session
        session = parse_session_jsonl(session_id)

        if not session or not session["user_messages"]:
            print(json.dumps({"continue": True}))
            return

        if is_extraction_session(session):
            print(json.dumps({"continue": True}))
            return

        # Check if we already have this session synced
        existing_session = find_session_by_id(session_id)
        if existing_session:
            # Check if memories already extracted
            content = existing_session.read_text()
            if "memories_extracted: true" in content.lower():
                print(json.dumps({"continue": True}))
                return
            session_path = existing_session
        else:
            # Write session to Obsidian
            created = (
                datetime.fromisoformat(session["created_at"].replace("Z", "+00:00"))
                if session["created_at"]
                else datetime.now()
            )
            session_path = write_session(
                session_id=session["session_id"],
                created=created,
                work_type=session["work_type"],
                first_message=session["first_message"],
                last_message=session["last_message"],
                user_messages=session["user_messages"],
                assistant_messages=session["assistant_messages"],
                tool_calls=session["tool_calls"],
                files_touched=session["files_touched"],
                token_estimate=session["token_estimate"],
            )

        if not session_path:
            print(json.dumps({"continue": True}))
            return

        # Detect triggers
        triggers = detect_triggers(session["user_messages"])

        # Build extraction prompt
        prompt = build_extraction_prompt(session, triggers)

        # Call Claude for extraction
        memories = call_claude_for_extraction(prompt)

        # Write memories to Obsidian
        session_rel_path = f"Claude/Sessions/{session_path.name}" if session_path else None
        memories_written = 0

        for mem in memories:
            result = write_memory(
                memory_type=mem["type"],
                title=mem["title"],
                summary=mem["summary"],
                reasoning=mem.get("reasoning", ""),
                confidence=float(mem["confidence"]),
                entities=mem.get("entities", []),
                context=mem.get("context", ""),
                source_session=session_rel_path,
                category=mem.get("category", "technical"),
            )
            if result:
                memories_written += 1

        # Update session to mark memories as extracted
        if session_path and memories_written > 0:
            update_frontmatter(session_path, {"memories_extracted": True})

        print(json.dumps({"continue": True}))
    finally:
        release_session_lock(lock_path)


if __name__ == "__main__":
    main()
