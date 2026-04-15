#!/usr/bin/env bash
#
# install-weekly-synthesis.sh - Install the weekly synthesis LaunchAgent
#
# Substitutes template placeholders, writes the result to ~/Library/LaunchAgents/
# and loads the agent by default using modern launchctl semantics.
#
# Usage:
#   install-weekly-synthesis.sh              # Install and load
#   install-weekly-synthesis.sh --no-load    # Install without loading
#   install-weekly-synthesis.sh --uninstall  # Remove

set -euo pipefail

LABEL="com.user.claude-weekly-synthesis"
TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$TEMPLATE_DIR/${LABEL}.plist.template"
DOTFILES_ROOT="$(cd "$TEMPLATE_DIR/../.." && pwd)"
AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$AGENTS_DIR/${LABEL}.plist"
LOG_FILE="$HOME/Library/Logs/claude-weekly-synthesis.log"
GUI_DOMAIN="gui/$(id -u)"
LOAD_AGENT=true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
	cat <<EOF
install-weekly-synthesis.sh - Install the weekly synthesis LaunchAgent

USAGE:
  install-weekly-synthesis.sh [--no-load]
  install-weekly-synthesis.sh --uninstall

OPTIONS:
  --no-load     Install/update plist but do not load it into launchctl
  --uninstall   Boot out and remove the LaunchAgent plist
  --help        Show this help
EOF
}

bootout_agent() {
	launchctl bootout "$GUI_DOMAIN" "$PLIST_FILE" >/dev/null 2>&1 ||
		launchctl bootout "$GUI_DOMAIN/$LABEL" >/dev/null 2>&1 || true
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--no-load)
		LOAD_AGENT=false
		shift
		;;
	--uninstall)
		ACTION="uninstall"
		shift
		;;
	--help | -h)
		show_help
		exit 0
		;;
	*)
		echo -e "${RED}Error: Unknown option $1${NC}" >&2
		show_help >&2
		exit 1
		;;
	esac
done

# --- Uninstall ---
if [[ "${ACTION:-install}" == "uninstall" ]]; then
	echo -e "${BLUE}Uninstalling $LABEL...${NC}"

	bootout_agent
	echo -e "  Removed from launchctl (if loaded)"

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

SCRIPT_PATH="$DOTFILES_ROOT/scripts/obsidian/weekly-synthesis.sh"
if [[ ! -f "$SCRIPT_PATH" ]]; then
	echo -e "${RED}Error: weekly-synthesis.sh not found at $SCRIPT_PATH${NC}" >&2
	echo -e "${RED}Ensure you are running from the dotfiles repo.${NC}" >&2
	exit 1
fi

mkdir -p "$AGENTS_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Substitute template placeholders with actual paths
sed \
	-e "s|__HOME__|${HOME}|g" \
	-e "s|__DOTFILES_ROOT__|${DOTFILES_ROOT}|g" \
	"$TEMPLATE_FILE" >"$PLIST_FILE"
chmod 644 "$PLIST_FILE"

if ! plutil -lint "$PLIST_FILE" >/dev/null; then
	echo -e "${RED}Error: generated plist failed validation: $PLIST_FILE${NC}" >&2
	exit 1
fi

echo -e "${GREEN}Installed: $PLIST_FILE${NC}"

if $LOAD_AGENT; then
	bootout_agent
	launchctl bootstrap "$GUI_DOMAIN" "$PLIST_FILE"
	launchctl enable "$GUI_DOMAIN/$LABEL" >/dev/null 2>&1 || true
	echo -e "${GREEN}Loaded LaunchAgent: $LABEL${NC}"
else
	echo -e "${YELLOW}Installed but not loaded (--no-load).${NC}"
fi

echo ""
echo -e "${BLUE}--- Verification ---${NC}"
echo -e "  Plist: $PLIST_FILE"
echo -e "  Script: $SCRIPT_PATH"
echo -e "  Log: $LOG_FILE"
if $LOAD_AGENT; then
	echo -e "  launchctl print $GUI_DOMAIN/$LABEL"
else
	echo -e "  launchctl bootstrap $GUI_DOMAIN $PLIST_FILE"
fi
echo -e "  bash $SCRIPT_PATH --verbose"
echo -e "${YELLOW}Schedule: every Sunday at 09:00 local time.${NC}"
