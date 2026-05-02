#!/usr/bin/env bash
set -euo pipefail

# Legacy distant.nvim setup check. The active Neovim config no longer enables
# distant.nvim by default, so this check is opt-in and non-blocking unless
# explicitly requested.
if [[ "${ENABLE_DISTANT_LEGACY_TEST:-false}" != "true" ]]; then
    echo "SKIP distant.nvim legacy check (set ENABLE_DISTANT_LEGACY_TEST=true to run)"
    exit 0
fi

echo "Testing legacy distant.nvim configuration..."

# Check distant binary
echo "1. Checking distant binary..."
DISTANT_BIN="$HOME/.local/share/nvim/distant/distant.bin"
if [ -f "$DISTANT_BIN" ]; then
    echo "   PASS binary found at: $DISTANT_BIN"
    echo "   Version: $($DISTANT_BIN --version)"
else
    echo "   FAIL binary not found"
    exit 1
fi

# Run Neovim health check
echo ""
echo "2. Running Neovim health check for distant..."
nvim --headless +"checkhealth distant" +"qa" 2>&1 | grep -A20 "distant"

echo ""
echo "3. Available distant commands in Neovim:"
echo "   :DistantConnect ssh://hostname  - Connect to remote host"
echo "   :DistantOpen /path/to/file      - Open remote file"
echo "   :DistantShell                    - Open remote shell"
echo "   :DistantSessionInfo              - Show connection info"
echo ""
echo "4. To connect to EC2 instance:"
echo "   :DistantConnect ssh://i-059fbc6cbc4bb45df"
echo ""
echo "Legacy setup check complete. Restart Neovim and try :DistantConnect if the plugin is re-enabled."
