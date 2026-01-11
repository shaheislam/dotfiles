#!/usr/bin/env python3
"""
PostToolUse Hook - Log significant tool actions to audit trail.

This hook triggers after certain tools are used and:
1. Records the tool use to the audit trail
2. Writes individual markdown files per action
3. Organizes by date for easy browsing

Hook Input (stdin JSON):
{
  "hook_type": "PostToolUse",
  "session_id": "abc123",
  "tool_name": "Edit",
  "tool_input": {"file_path": "/path/to/file.ts"},
  "tool_result": "File edited successfully"
}

Hook Output (stdout JSON):
{
  "continue": true
}
"""

import json
import sys
from pathlib import Path
from typing import Dict, Any

# Add lib to path
sys.path.insert(0, str(Path(__file__).parent))

from lib.config import AUDIT_TOOLS
from lib.markdown_writer import write_audit


def should_log_tool(tool_name: str) -> bool:
    """
    Determine if this tool use should be logged.

    Only log significant tools that modify files or execute commands.
    """
    return tool_name in AUDIT_TOOLS


def extract_action_details(tool_name: str, tool_input: Dict[str, Any]) -> Dict[str, Any]:
    """Extract relevant details from tool input based on tool type."""
    details = {'tool': tool_name}

    if tool_name == 'Edit':
        details['file_path'] = tool_input.get('file_path', '')
        details['old_string'] = tool_input.get('old_string', '')[:100] + '...' if tool_input.get('old_string', '') else ''
        details['action'] = 'edit'

    elif tool_name == 'Write':
        details['file_path'] = tool_input.get('file_path', '')
        content = tool_input.get('content', '')
        details['content_preview'] = content[:100] + '...' if len(content) > 100 else content
        details['action'] = 'write'

    elif tool_name == 'Bash':
        details['command'] = tool_input.get('command', '')[:200]
        details['action'] = 'bash'

    elif tool_name == 'Task':
        details['description'] = tool_input.get('description', '')
        details['subagent_type'] = tool_input.get('subagent_type', '')
        details['action'] = 'task'

    elif tool_name == 'WebFetch':
        details['url'] = tool_input.get('url', '')
        details['action'] = 'web_fetch'

    elif tool_name == 'WebSearch':
        details['query'] = tool_input.get('query', '')
        details['action'] = 'web_search'

    return details


def determine_success(tool_result: str) -> bool:
    """Determine if the tool use was successful based on result."""
    if not tool_result:
        return True  # Assume success if no result

    result_lower = tool_result.lower()

    # Check for error indicators
    error_indicators = [
        'error', 'failed', 'exception', 'traceback',
        'permission denied', 'not found', 'does not exist'
    ]

    return not any(indicator in result_lower for indicator in error_indicators)


def main():
    """Main hook entry point."""
    # Read hook input from stdin
    try:
        input_data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, Exception):
        print(json.dumps({"continue": True}))
        return

    tool_name = input_data.get('tool_name', '')
    session_id = input_data.get('session_id', '')
    tool_input = input_data.get('tool_input', {})
    tool_result = input_data.get('tool_result', '')

    # Check if we should log this tool
    if not should_log_tool(tool_name):
        print(json.dumps({"continue": True}))
        return

    # Extract action details
    action_details = extract_action_details(tool_name, tool_input)

    # Determine success
    success = determine_success(str(tool_result) if tool_result else '')

    # Write audit entry
    write_audit(
        tool_name=tool_name,
        session_id=session_id,
        action_details=action_details,
        success=success,
        duration_ms=None  # Not available in hook input
    )

    print(json.dumps({"continue": True}))


if __name__ == "__main__":
    main()
