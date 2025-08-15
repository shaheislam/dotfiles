#!/usr/bin/env python3
"""
User Prompt Context Enhancement Hook
Adds useful context to user prompts like timestamp, git info, and environment
"""

import json
import os
import sys
import datetime
import subprocess
import re

def get_git_info():
    """Get current git branch and status"""
    try:
        branch = subprocess.check_output(['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                                       stderr=subprocess.DEVNULL).decode().strip()

        status = subprocess.check_output(['git', 'status', '--porcelain'],
                                       stderr=subprocess.DEVNULL).decode()

        modified_files = len([l for l in status.splitlines() if l.strip()])

        return f"Git: {branch} ({modified_files} modified files)"
    except:
        return None

def get_recent_bash_command():
    """Get the most recent bash command from the log"""
    try:
        bash_log_file = os.path.join(os.path.dirname(__file__), '..', 'bash_commands.json')
        if os.path.exists(bash_log_file):
            with open(bash_log_file, 'r') as f:
                logs = json.load(f)
            if logs:
                # Get the most recent command
                recent = logs[-1]
                command = recent.get('command', '')
                if command:
                    return f"Last bash: {command}"
        return None
    except:
        return None

def check_for_secrets(prompt: str) -> list[str]:
    """Check if prompt contains potential secrets"""
    warnings = []

    # Patterns that might indicate secrets
    secret_patterns = [
        (r'(?i)\b(password|passwd|pwd)\s*[:=]\s*\S+', "Password"),
        (r'(?i)\b(api[_-]?key|apikey)\s*[:=]\s*\S+', "API Key"),
        (r'(?i)\b(secret|token)\s*[:=]\s*\S+', "Secret/Token"),
        (r'\b[A-Z0-9]{20,}\b', "Potential secret (long uppercase string)"),
        (r'(?i)bearer\s+[a-zA-Z0-9\-._~+/]+', "Bearer token"),
    ]

    for pattern, name in secret_patterns:
        if re.search(pattern, prompt):
            warnings.append(f"⚠️  WARNING: Potential {name} detected in prompt")

    return warnings

def main():
    try:
        # Read input from stdin
        input_data = json.loads(sys.stdin.read())

        prompt = input_data.get("prompt", "")

        # Check for secrets
        warnings = check_for_secrets(prompt)

        # Build context
        context_lines = []

        # Add timestamp
        context_lines.append(f"📅 Time: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

        # Add current directory
        context_lines.append(f"📁 Directory: {os.getcwd()}")

        # Add git info if available
        git_info = get_git_info()
        if git_info:
            context_lines.append(f"🔧 {git_info}")

        # Add recent bash command if available
        recent_bash = get_recent_bash_command()
        if recent_bash:
            context_lines.append(f"⚡ {recent_bash}")

        # Add Python version
        python_version = sys.version.split()[0]
        context_lines.append(f"🐍 Python: {python_version}")

        # Add any warnings
        if warnings:
            context_lines.extend(warnings)
            context_lines.append("")  # blank line

        # Output the context
        if context_lines:
            print("\n[Hook: Context Information]")
            for line in context_lines:
                print(line)
            print("")  # blank line after context

    except Exception as e:
        # Log error but don't block
        print(f"Hook error: {e}", file=sys.stderr)
        sys.exit(0)

if __name__ == "__main__":
    main()
