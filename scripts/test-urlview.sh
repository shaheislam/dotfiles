#!/bin/bash
# Debug script for testing urlview in tmux

echo "Testing urlview setup..."
echo ""

# Check urlview installation
if command -v urlview >/dev/null 2>&1; then
    echo "✅ urlview is installed at: $(which urlview)"
else
    echo "❌ urlview is NOT installed"
    echo "   Run: brew install urlview"
    exit 1
fi

# Check config file
if [ -f "$HOME/.urlview" ]; then
    echo "✅ urlview config exists at: $HOME/.urlview"
else
    echo "❌ urlview config NOT found"
    echo "   Should be at: $HOME/.urlview"
fi

# Check Firefox script
SCRIPT_PATH="/Users/shahe/dotfiles/scripts/urlview-firefox.sh"
if [ -f "$SCRIPT_PATH" ]; then
    if [ -x "$SCRIPT_PATH" ]; then
        echo "✅ Firefox script exists and is executable"
    else
        echo "⚠️  Firefox script exists but is NOT executable"
        echo "   Run: chmod +x $SCRIPT_PATH"
    fi
else
    echo "❌ Firefox script NOT found at: $SCRIPT_PATH"
fi

# Test URL extraction
echo ""
echo "Testing URL extraction..."
TEST_FILE="/tmp/test-urlview-$$"
cat > "$TEST_FILE" << 'EOF'
Here are some test URLs:
https://github.com/test/repo
http://www.google.com
www.example.com
ftp://ftp.test.com/file.txt
mailto:test@example.com
EOF

echo "Test content saved to: $TEST_FILE"
echo ""
echo "URLs that should be found:"
grep -Eo '(https?://[^ ]+|www\.[^ ]+|ftp://[^ ]+|mailto:[^ ]+)' "$TEST_FILE"

echo ""
echo "To test urlview manually, run:"
echo "  urlview $TEST_FILE"
echo ""
echo "In tmux, press Ctrl+Space, then 'u' to test the plugin"

# Clean up
rm -f "$TEST_FILE"