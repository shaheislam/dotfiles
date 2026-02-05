#!/usr/bin/env bash
# gmailclean setup script
# Creates virtual environment with uv and installs dependencies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "=== gmailclean Setup ==="

# Check for uv
if ! command -v uv &>/dev/null; then
    echo "Error: 'uv' not found. Install with: brew install uv"
    exit 1
fi

# Create venv and install deps
echo "Creating virtual environment..."
cd "$SCRIPT_DIR"
uv venv "$VENV_DIR"
uv pip install -r <(echo "
google-api-python-client>=2.100.0
google-auth-httplib2>=0.2.0
google-auth-oauthlib>=1.2.0
rich>=13.0.0
")

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Set up Gmail API credentials:"
echo "     - Go to https://console.cloud.google.com/apis/credentials"
echo "     - Create project > Enable Gmail API > Create OAuth 2.0 Client ID"
echo "     - Download credentials.json"
echo "     - Save to: ~/.config/gmailclean/credentials.json"
echo ""
echo "  2. Run gmailclean:"
echo "     gmailclean scan          # Scan for subscriptions"
echo "     gmailclean unsubscribe   # Unsubscribe from newsletters"
echo "     gmailclean organize      # Create labels/filters"
echo "     gmailclean report        # Inbox health report"
echo "     gmailclean nuke          # Full cleanup pipeline"
