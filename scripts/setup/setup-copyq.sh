#!/usr/bin/env bash
# Setup CopyQ clipboard manager with power-user configuration
# Installs from GitHub releases (not Homebrew, which is deprecated)
# This script downloads CopyQ, installs it, and imports custom commands

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
COMMANDS_FILE="$DOTFILES_DIR/.config/copyq/copyq-commands.ini"

# CopyQ version and download URL
COPYQ_VERSION="13.0.0"
COPYQ_DMG_URL="https://github.com/hluk/CopyQ/releases/download/v${COPYQ_VERSION}/CopyQ-macos-12-m1.dmg.zip"
# SHA256 checksum for integrity verification (from GitHub API)
EXPECTED_SHA256="2eb743cc57a97fde6c71d6ec0587408ae2beb41939699117d32b74e68882e77e"

echo -e "${BLUE}Setting up CopyQ clipboard manager...${NC}"

# Check if running on macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${YELLOW}CopyQ setup is only configured for macOS. Skipping...${NC}"
    exit 0
fi

# Function to install CopyQ from GitHub
install_copyq_from_github() {
    echo -e "${BLUE}Downloading CopyQ v${COPYQ_VERSION} from GitHub...${NC}"

    local tmp_dir="/tmp/copyq-install-$$"
    mkdir -p "$tmp_dir"

    # Download
    if ! curl -fsSL "$COPYQ_DMG_URL" -o "$tmp_dir/copyq.dmg.zip"; then
        echo -e "${RED}Failed to download CopyQ from GitHub${NC}"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Verify SHA256 checksum for security
    echo -e "${BLUE}Verifying SHA256 checksum...${NC}"
    ACTUAL_SHA256=$(shasum -a 256 "$tmp_dir/copyq.dmg.zip" | awk '{print $1}')
    if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
        echo -e "${RED}SECURITY WARNING: SHA256 checksum mismatch!${NC}"
        echo "Expected: $EXPECTED_SHA256"
        echo "Got:      $ACTUAL_SHA256"
        echo "Aborting installation - file may be corrupted or tampered with."
        rm -rf "$tmp_dir"
        return 1
    fi
    echo -e "${GREEN}SHA256 checksum verified successfully${NC}"

    # Extract zip
    echo -e "${BLUE}Extracting...${NC}"
    unzip -q -o "$tmp_dir/copyq.dmg.zip" -d "$tmp_dir"

    # Find the DMG file (named CopyQ.dmg after extraction)
    local dmg_file="$tmp_dir/CopyQ.dmg"
    if [[ ! -f "$dmg_file" ]]; then
        # Fallback: find any .dmg file
        dmg_file=$(find "$tmp_dir" -name "*.dmg" -type f | head -1)
    fi

    if [[ -z "$dmg_file" ]] || [[ ! -f "$dmg_file" ]]; then
        echo -e "${RED}Could not find DMG file in download${NC}"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Mount DMG
    echo -e "${BLUE}Mounting disk image...${NC}"
    hdiutil attach "$dmg_file" -nobrowse -quiet

    # Find the mounted volume (volume name is dynamic, e.g., copyq-13.0.0-gfa209998-v13.0.0-Darwin)
    sleep 1
    local mount_point
    mount_point=$(find /Volumes -maxdepth 1 -type d -name "copyq-*" 2>/dev/null | head -1)

    if [[ -z "$mount_point" ]] || [[ ! -d "$mount_point" ]]; then
        echo -e "${RED}Could not find mounted CopyQ volume${NC}"
        rm -rf "$tmp_dir"
        return 1
    fi

    if [[ ! -d "$mount_point/CopyQ.app" ]]; then
        echo -e "${RED}Could not find CopyQ.app in mounted volume: $mount_point${NC}"
        hdiutil detach "$mount_point" -quiet 2>/dev/null || true
        rm -rf "$tmp_dir"
        return 1
    fi

    # Copy to Applications
    echo -e "${BLUE}Installing to /Applications...${NC}"
    if [[ -d "/Applications/CopyQ.app" ]]; then
        echo -e "${YELLOW}Removing existing CopyQ installation...${NC}"
        rm -rf "/Applications/CopyQ.app"
    fi

    cp -R "$mount_point/CopyQ.app" /Applications/

    # Unmount DMG
    hdiutil detach "$mount_point" -quiet 2>/dev/null || true

    # Remove quarantine attribute (bypass Gatekeeper)
    echo -e "${BLUE}Removing quarantine attribute...${NC}"
    xattr -cr /Applications/CopyQ.app 2>/dev/null || true

    # Ad-hoc code sign for macOS Sequoia compatibility
    # Required because CopyQ is not Apple-signed but checksum is verified
    echo -e "${BLUE}Applying ad-hoc code signature for macOS Sequoia...${NC}"
    if codesign --force --deep --sign - /Applications/CopyQ.app 2>/dev/null; then
        echo -e "${GREEN}Ad-hoc code signature applied successfully${NC}"
    else
        echo -e "${YELLOW}Warning: Ad-hoc signing failed. CopyQ may not launch on macOS Sequoia.${NC}"
        echo -e "${YELLOW}Try running manually: codesign --force --deep --sign - /Applications/CopyQ.app${NC}"
    fi

    # Cleanup
    rm -rf "$tmp_dir"

    echo -e "${GREEN}CopyQ v${COPYQ_VERSION} installed successfully${NC}"
    return 0
}

# Check if CopyQ is installed in /Applications
if [[ ! -d "/Applications/CopyQ.app" ]]; then
    install_copyq_from_github
fi

# Verify installation
if [[ ! -d "/Applications/CopyQ.app" ]]; then
    echo -e "${RED}CopyQ installation failed. Please install manually from:${NC}"
    echo "  https://github.com/hluk/CopyQ/releases"
    exit 1
fi

# Add CopyQ to PATH if not already available
COPYQ_BIN="/Applications/CopyQ.app/Contents/MacOS/copyq"
if [[ -x "$COPYQ_BIN" ]] && ! command -v copyq &>/dev/null; then
    export PATH="/Applications/CopyQ.app/Contents/MacOS:$PATH"
fi

# Start CopyQ if not running (needed for config commands)
if ! pgrep -x "CopyQ" >/dev/null 2>&1; then
    echo -e "${BLUE}Starting CopyQ...${NC}"
    open -a CopyQ
    sleep 3 # Give it time to start
fi

# Wait for copyq CLI to be responsive
echo -e "${BLUE}Waiting for CopyQ to be ready...${NC}"
for _ in {1..10}; do
    if "$COPYQ_BIN" version &>/dev/null; then
        break
    fi
    sleep 1
done

# Import custom commands
if [[ -f "$COMMANDS_FILE" ]]; then
    echo -e "${BLUE}Importing CopyQ commands...${NC}"
    if "$COPYQ_BIN" importCommands "$COMMANDS_FILE" 2>/dev/null; then
        echo -e "${GREEN}Commands imported successfully${NC}"
    else
        echo -e "${YELLOW}Warning: Could not import commands. CopyQ may not be fully started.${NC}"
        echo -e "${YELLOW}Try running: copyq importCommands $COMMANDS_FILE${NC}"
    fi
else
    echo -e "${YELLOW}Commands file not found: $COMMANDS_FILE${NC}"
fi

# Configure CopyQ settings
echo -e "${BLUE}Configuring CopyQ settings...${NC}"

# Core settings
"$COPYQ_BIN" config activate_closes true 2>/dev/null || true
"$COPYQ_BIN" config activate_focuses true 2>/dev/null || true
"$COPYQ_BIN" config activate_pastes true 2>/dev/null || true
"$COPYQ_BIN" config maxitems 1000 2>/dev/null || true
"$COPYQ_BIN" config tray_items 20 2>/dev/null || true
"$COPYQ_BIN" config clipboard_tab "&clipboard" 2>/dev/null || true
"$COPYQ_BIN" config edit_ctrl_return true 2>/dev/null || true
"$COPYQ_BIN" config move true 2>/dev/null || true
"$COPYQ_BIN" config check_clipboard true 2>/dev/null || true
"$COPYQ_BIN" config confirm_exit false 2>/dev/null || true
"$COPYQ_BIN" config autostart true 2>/dev/null || true
"$COPYQ_BIN" config hide_toolbar_labels false 2>/dev/null || true # Show text labels on toolbar

# Create Queue tab for paste queue feature
"$COPYQ_BIN" tab Queue 2>/dev/null || true

echo -e "${GREEN}CopyQ setup complete!${NC}"
echo ""
echo -e "${GREEN}CopyQ keyboard shortcuts configured${NC}"
echo ""
echo -e "${BLUE}Requirements:${NC}"
echo "1. Grant Accessibility access:"
echo "   System Settings → Privacy & Security → Accessibility → Enable CopyQ"
echo ""
echo -e "${BLUE}Keyboard shortcuts available:${NC}"
echo "  Cmd+Shift+V     - Open clipboard history (configure in CopyQ Preferences → Shortcuts)"
echo "  Ctrl+1-5        - Quick paste from history slots"
echo "  Ctrl+J          - Format JSON"
echo "  Ctrl+B          - Base64 decode"
echo "  Ctrl+Shift+B    - Base64 encode"
echo "  Ctrl+U          - URL decode"
echo "  Ctrl+Shift+U    - URL encode"
echo "  Ctrl+Alt+A      - Parse AWS ARN"
echo "  Ctrl+Alt+J      - Decode JWT"
echo "  Ctrl+Shift+A    - Strip ANSI colors"
echo "  Ctrl+Shift+T    - Trim whitespace"
echo "  Ctrl+D          - Insert date/time"
echo ""
echo -e "${BLUE}Security features enabled:${NC}"
echo "  - 1Password, Bitwarden, Keychain Access ignored"
echo "  - AWS credentials automatically blocked"
echo "  - All items tagged with source app + timestamp"
echo ""
echo "Documentation: ~/dotfiles/docs/copyq.md"
