#!/usr/bin/env bash
#
# install-weekly-synthesis.sh - Install the weekly synthesis LaunchAgent
#
# Substitutes __HOME__ in the plist template and writes the result to
# ~/Library/LaunchAgents/. Does NOT load the agent — you must do that manually.
#
# Usage:
#   install-weekly-synthesis.sh            # Install
#   install-weekly-synthesis.sh --uninstall # Remove

set -euo pipefail

LABEL="com.user.claude-weekly-synthesis"
TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$TEMPLATE_DIR/${LABEL}.plist.template"
AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$AGENTS_DIR/${LABEL}.plist"
LOG_FILE="$HOME/Library/Logs/claude-weekly-synthesis.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Uninstall ---
if [[ "${1:-}" == "--uninstall" ]]; then
    echo -e "${BLUE}Uninstalling $LABEL...${NC}"

    # Unload if currently loaded (ignore errors — may not be loaded)
    if launchctl list "$LABEL" &>/dev/null 2>&1; then
        launchctl unload "$PLIST_FILE" 2>/dev/null || true
        echo -e "  Unloaded from launchctl"
    fi

    if [[ -f "$PLIST_FILE" ]]; then
        rm -f "$PLIST_FILE"
        echo -e "  Removed: $PLIST_FILE"
    else
        echo -e "  ${YELLOW}Plist not found (already removed?): $PLIST_FILE${NC}"
    fi

    echo -e "${GREEN}Uninstalled.${NC}"
    echo ""
    echo -e "  Log file left at: $LOG_FILE (remove manually if desired)"
    exit 0
fi

# --- Install ---
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo -e "${RED}Error: Template not found: $TEMPLATE_FILE${NC}" >&2
    exit 1
fi

SCRIPT_PATH="$HOME/dotfiles/scripts/obsidian/weekly-synthesis.sh"
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo -e "${RED}Error: weekly-synthesis.sh not found at $SCRIPT_PATH${NC}" >&2
    echo -e "${RED}Ensure dotfiles are stowed before installing the LaunchAgent.${NC}" >&2
    exit 1
fi

mkdir -p "$AGENTS_DIR"

# Substitute __HOME__ with actual $HOME
sed "s|__HOME__|${HOME}|g" "$TEMPLATE_FILE" >"$PLIST_FILE"
chmod 644 "$PLIST_FILE"

echo -e "${GREEN}Installed: $PLIST_FILE${NC}"
echo ""
echo -e "${BLUE}--- Next steps ---${NC}"
echo ""
echo -e "  1. Validate the plist:"
echo -e "     plutil -lint $PLIST_FILE"
echo ""
echo -e "  2. Load the LaunchAgent (enable scheduling):"
echo -e "     launchctl load $PLIST_FILE"
echo ""
echo -e "  3. Verify it is registered:"
echo -e "     launchctl list $LABEL"
echo ""
echo -e "  4. Run manually to test now:"
echo -e "     launchctl start $LABEL"
echo -e "     # or directly:"
echo -e "     bash $SCRIPT_PATH --verbose"
echo ""
echo -e "  5. Watch logs:"
echo -e "     tail -f $LOG_FILE"
echo ""
echo -e "${YELLOW}The agent is NOT loaded yet. Run step 2 when ready.${NC}"
echo -e "${YELLOW}Schedule: every Sunday at 09:00 local time.${NC}"
echo ""
echo -e "To uninstall later:"
echo -e "  bash $TEMPLATE_DIR/install-weekly-synthesis.sh --uninstall"
