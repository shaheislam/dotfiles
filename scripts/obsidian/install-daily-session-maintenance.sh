#!/usr/bin/env bash
# Install the daily Claude session reconcile/distillation LaunchAgent.

set -euo pipefail

LABEL="com.user.claude-daily-session-maintenance"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/${LABEL}.plist.template"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$AGENTS_DIR/${LABEL}.plist"
LOG_FILE="$HOME/Library/Logs/claude-daily-session-maintenance.log"
GUI_DOMAIN="gui/$(id -u)"
LOAD_AGENT=true
ACTION="install"

show_help() {
    cat <<EOF
install-daily-session-maintenance.sh - Install daily Claude session maintenance

USAGE:
  install-daily-session-maintenance.sh [--no-load]
  install-daily-session-maintenance.sh --uninstall

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
        echo "Error: Unknown option $1" >&2
        show_help >&2
        exit 1
        ;;
    esac
done

if [[ "$ACTION" == "uninstall" ]]; then
    bootout_agent
    rm -f "$PLIST_FILE"
    echo "Uninstalled: $LABEL"
    exit 0
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "Error: Template not found: $TEMPLATE_FILE" >&2
    exit 1
fi

if [[ ! -f "$DOTFILES_ROOT/scripts/obsidian/daily-session-maintenance.sh" ]]; then
    echo "Error: daily-session-maintenance.sh not found" >&2
    exit 1
fi

mkdir -p "$AGENTS_DIR" "$(dirname "$LOG_FILE")"

sed \
    -e "s|__HOME__|${HOME}|g" \
    -e "s|__DOTFILES_ROOT__|${DOTFILES_ROOT}|g" \
    "$TEMPLATE_FILE" >"$PLIST_FILE"
chmod 644 "$PLIST_FILE"

if ! plutil -lint "$PLIST_FILE" >/dev/null; then
    echo "Error: generated plist failed validation: $PLIST_FILE" >&2
    exit 1
fi

echo "Installed: $PLIST_FILE"

if $LOAD_AGENT; then
    bootout_agent
    launchctl bootstrap "$GUI_DOMAIN" "$PLIST_FILE"
    launchctl enable "$GUI_DOMAIN/$LABEL" >/dev/null 2>&1 || true
    echo "Loaded LaunchAgent: $LABEL"
else
    echo "Installed but not loaded (--no-load)."
fi

echo "Schedule: daily at 09:30 local time"
echo "Manual run: bash $DOTFILES_ROOT/scripts/obsidian/daily-session-maintenance.sh"
