#!/usr/bin/env python3

import json
import sys
import subprocess
from pathlib import Path


def play_audio_file(file_path):
    """Play an audio file using afplay (macOS built-in)"""
    try:
        subprocess.run(
            ["afplay", str(file_path)],
            capture_output=True,
            text=True,
            timeout=10
        )
    except Exception as e:
        print(f"Failed to play audio: {e}", file=sys.stderr)


def main():
    try:
        # Read input data from stdin
        try:
            input_data = json.load(sys.stdin)
        except:
            # If no JSON input, assume it's a Stop event
            input_data = {"notification_type": "stop"}
        
        # Log hook execution for debugging
        log_file = Path(__file__).parent.parent / "audio_hook.log"
        with open(log_file, "a") as f:
            f.write(f"{json.dumps(input_data)}\n")
        
        # Get audio directory
        audio_dir = Path(__file__).parent.parent / "audio"
        
        # Get notification type to determine which sound to play
        notification_type = input_data.get("notification_type", "stop")
        
        # Always use Glass system sound for all notifications
        sound = "Glass"
        print(f"🔊 Playing system sound: {sound}")
        
        # Use afplay for more reliable audio playback
        try:
            subprocess.run(
                ["afplay", f"/System/Library/Sounds/{sound}.aiff"],
                capture_output=True,
                text=True,
                timeout=5
            )
        except:
            # Fallback to osascript
            subprocess.run(
                ["osascript", "-e", f'beep sound "{sound}"'],
                capture_output=True,
                text=True,
                timeout=5
            )
        
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON input: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error in audio hook: {e}", file=sys.stderr)
        sys.exit(1)


main()