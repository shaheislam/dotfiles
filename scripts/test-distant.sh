#!/bin/bash

# Test distant.nvim setup
echo "Testing distant.nvim configuration..."

# Check distant binary
echo "1. Checking distant binary..."
DISTANT_BIN="$HOME/.local/share/nvim/distant/distant.bin"
if [ -f "$DISTANT_BIN" ]; then
    echo "   ✓ Binary found at: $DISTANT_BIN"
    echo "   Version: $($DISTANT_BIN --version)"
else
    echo "   ✗ Binary not found"
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
echo "Setup complete! Restart Neovim and try :DistantConnect"