#!/usr/bin/env python3

import json
import sys
import subprocess
from pathlib import Path


def send_notification(title, message, sound=None):
    """Send a macOS notification using osascript"""
    try:
        # Base AppleScript command
        script = f'display notification "{message}" with title "{title}"'

        # Add sound if specified
        if sound:
            script += f' sound name "{sound}"'

        subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            text=True,
            timeout=5
        )
    except Exception as e:
        print(f"Failed to send notification: {e}", file=sys.stderr)


def main():
    try:
        # Read input data from stdin
        input_data = json.load(sys.stdin)

        # Get notification details
        notification_type = input_data.get("notification_type", "info")
        message = input_data.get("message", "Claude Code notification")

        # Customize notification based on type
        if notification_type == "error":
            title = "🚨 Claude Code Error"
            sound = "Basso"
        elif notification_type == "warning":
            title = "⚠️ Claude Code Warning"
            sound = "Sosumi"
        elif notification_type == "success":
            title = "✅ Claude Code Success"
            sound = "Glass"
        else:
            title = "🤖 Claude Code"
            sound = "Blow"

        # Truncate long messages
        if len(message) > 100:
            message = message[:97] + "..."

        # Send the notification
        send_notification(title, message, sound)

        # Also log to console for debugging
        print(f"📢 Notification sent: {title} - {message}")

    except json.JSONDecodeError as e:
        print(f"Error parsing JSON input: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error in notification hook: {e}", file=sys.stderr)
        sys.exit(1)


main()
