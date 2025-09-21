#!/bin/bash
# Setup K9s by symlinking configuration from dotfiles

set -e

echo "🚀 Setting up K9s configuration from dotfiles..."
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DOTFILES_DIR="$HOME/dotfiles"

# K9s uses different config locations on macOS vs Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS uses Application Support
    K9S_CONFIG_DIR="$HOME/Library/Application Support/k9s"
else
    # Linux uses .config
    K9S_CONFIG_DIR="$HOME/.config/k9s"
fi

# Check if dotfiles directory exists
if [ ! -d "$DOTFILES_DIR/.config/k9s" ]; then
    echo -e "${RED}Error: K9s config not found in dotfiles${NC}"
    echo "Expected location: $DOTFILES_DIR/.config/k9s"
    exit 1
fi

# Remove existing k9s config if it exists and is not a symlink
if [ -e "$K9S_CONFIG_DIR" ] && [ ! -L "$K9S_CONFIG_DIR" ]; then
    echo -e "${YELLOW}Backing up existing k9s configuration...${NC}"
    mv "$K9S_CONFIG_DIR" "$K9S_CONFIG_DIR.backup.$(date +%Y%m%d-%H%M%S)"
fi

# Create symlink to dotfiles k9s config
echo -e "${BLUE}Creating symlink to dotfiles k9s configuration...${NC}"
ln -sfn "$DOTFILES_DIR/.config/k9s" "$K9S_CONFIG_DIR"

# Verify symlink was created
if [ -L "$K9S_CONFIG_DIR" ]; then
    echo -e "${GREEN}✓${NC} K9s configuration linked successfully"
else
    echo -e "${RED}✗${NC} Failed to create symlink"
    exit 1
fi

# Check for required tools
echo ""
echo -e "${BLUE}Checking for required tools...${NC}"

check_tool() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "${YELLOW}⚠${NC}  $1 is not installed"
        return 1
    fi
}

# Check essential tools
check_tool "k9s"
check_tool "kubectl"

# Check optional but recommended tools
echo ""
echo -e "${BLUE}Checking optional tools for plugins...${NC}"
check_tool "stern" || echo "  Install with: brew install stern"
check_tool "dive" || echo "  Install with: brew install dive"
check_tool "trivy" || echo "  Install with: brew install trivy"
check_tool "helm" || echo "  Install with: brew install helm"

# Display configuration details
echo ""
echo -e "${GREEN}✅ K9s setup complete!${NC}"
echo ""
echo "Configuration files:"
echo "  • plugins.yaml  - Plugin shortcuts and commands"
echo "  • config.yaml   - Main K9s configuration"
echo "  • aliases.yaml  - Resource shortcuts (pp for pods, etc.)"
echo "  • hotkeys.yaml  - Custom keyboard shortcuts"
echo "  • skins/tokyo-night.yaml - Tokyo Night theme"
echo ""
echo "Key Plugin Shortcuts:"
echo "  ${BLUE}Debugging:${NC}"
echo "    Shift-D : Add debug container"
echo "    b       : Exec bash shell (with nvim detection)"
echo "    s       : Exec sh shell (with nvim detection)"
echo "    Shift-N : Enhanced shell (attempts nvim install)"
echo ""
echo "  ${BLUE}Editing & Viewing:${NC}"
echo "    e       : Edit in Neovim"
echo "    y       : Copy YAML to clipboard"
echo "    w       : Watch resource changes"
echo ""
echo "  ${BLUE}Operations:${NC}"
echo "    Shift-R : Restart deployment"
echo "    Shift-S : Scale deployment"
echo "    Shift-F : Interactive port-forward"
echo "    Shift-E : Show events"
echo ""
echo "  ${BLUE}Monitoring:${NC}"
echo "    Ctrl-L  : View logs with Stern"
echo "    t       : Show pod metrics"
echo "    d       : Dive into image layers"
echo ""
echo "  ${BLUE}Quick Navigation:${NC}"
echo "    Shift-1 : Jump to Pods"
echo "    Shift-2 : Jump to Deployments"
echo "    Shift-3 : Jump to Services"
echo "    Shift-9 : Jump to Nodes"
echo ""
echo "${BLUE}Neovim in Pods:${NC}"
echo "  • Shell commands (b/s) auto-detect nvim/vim in containers"
echo "  • Shift-N tries to install nvim if not present"
echo "  • Use scripts/install-nvim-in-pod.sh to pre-install nvim"
echo ""
echo "Start k9s to use your enhanced configuration!"