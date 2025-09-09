#!/bin/bash
# Fix urlview issues for tmux-urlview plugin

echo "=== Fixing tmux-urlview setup ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Install both URL extractors
echo "Step 1: Installing URL extractors..."
if ! command -v urlview >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing urlview...${NC}"
    brew install urlview
else
    echo -e "${GREEN}✅ urlview already installed${NC}"
fi

if ! command -v extract_url >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing extract_url (more reliable alternative)...${NC}"
    brew install extract_url
else
    echo -e "${GREEN}✅ extract_url already installed${NC}"
fi

# 2. Ensure config files are in place
echo ""
echo "Step 2: Setting up configuration files..."

# urlview config
if [ ! -f "$HOME/.urlview" ]; then
    if [ -f "$HOME/dotfiles/.urlview" ]; then
        ln -sf "$HOME/dotfiles/.urlview" "$HOME/.urlview"
        echo -e "${GREEN}✅ Linked .urlview config${NC}"
    else
        echo -e "${RED}❌ .urlview config not found in dotfiles${NC}"
    fi
else
    echo -e "${GREEN}✅ .urlview config exists${NC}"
fi

# extract_url config
if [ ! -f "$HOME/.extract_urlview" ]; then
    if [ -f "$HOME/dotfiles/.extract_urlview" ]; then
        ln -sf "$HOME/dotfiles/.extract_urlview" "$HOME/.extract_urlview"
        echo -e "${GREEN}✅ Linked .extract_urlview config${NC}"
    else
        echo -e "${YELLOW}⚠️  .extract_urlview config not found (optional)${NC}"
    fi
else
    echo -e "${GREEN}✅ .extract_urlview config exists${NC}"
fi

# 3. Check Firefox script
echo ""
echo "Step 3: Checking Firefox open script..."
SCRIPT_PATH="$HOME/dotfiles/scripts/urlview-firefox.sh"
if [ -f "$SCRIPT_PATH" ]; then
    chmod +x "$SCRIPT_PATH"
    echo -e "${GREEN}✅ Firefox script is executable${NC}"
else
    echo -e "${RED}❌ Firefox script not found at: $SCRIPT_PATH${NC}"
fi

# 4. Reinstall tmux-urlview plugin
echo ""
echo "Step 4: Refreshing tmux-urlview plugin..."
if [ -d "$HOME/.tmux/plugins/tmux-urlview" ]; then
    cd "$HOME/.tmux/plugins/tmux-urlview"
    git pull
    echo -e "${GREEN}✅ Updated tmux-urlview plugin${NC}"
else
    echo -e "${YELLOW}Installing tmux-urlview plugin...${NC}"
    git clone https://github.com/tmux-plugins/tmux-urlview "$HOME/.tmux/plugins/tmux-urlview"
fi

# 5. Create log directory
echo ""
echo "Step 5: Creating log directory..."
mkdir -p "$HOME/dotfiles/logs"
echo -e "${GREEN}✅ Log directory ready${NC}"

# 6. Test the setup
echo ""
echo "Step 6: Testing URL extraction..."
TEST_FILE="/tmp/test-urlview-$$"
cat > "$TEST_FILE" << 'EOF'
Test URLs:
https://github.com/example
http://www.google.com
www.example.com
EOF

echo "Using urlview:"
if command -v urlview >/dev/null 2>&1; then
    urlview < "$TEST_FILE" 2>&1 | head -3 || echo "  (urlview needs terminal interaction)"
fi

echo ""
echo "Using extract_url (preferred):"
if command -v extract_url >/dev/null 2>&1; then
    extract_url < "$TEST_FILE" 2>&1 | head -5
fi

rm -f "$TEST_FILE"

# 7. Final instructions
echo ""
echo "=== Setup Complete! ==="
echo ""
echo -e "${GREEN}To use in tmux:${NC}"
echo "  1. Start/restart tmux"
echo "  2. Press Ctrl+Space (prefix), then 'u'"
echo "  3. URLs from the current pane will be listed"
echo "  4. Select a URL to open in Firefox"
echo ""
echo -e "${YELLOW}If it still doesn't work:${NC}"
echo "  1. Make sure you have URLs visible in the tmux pane"
echo "  2. Try pressing Ctrl+Space, then Shift+I to reload plugins"
echo "  3. Check the log file: tail -f ~/dotfiles/logs/urlview.log"
echo ""
echo "The plugin will prefer extract_url if available (it's more reliable)."