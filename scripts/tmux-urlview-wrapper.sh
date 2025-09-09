#!/usr/bin/env bash
# Robust tmux-urlview wrapper that works across all devices

set -euo pipefail

# Configuration
LOGDIR="$HOME/dotfiles/logs"
LOGFILE="$LOGDIR/tmux-urlview-debug.log"
TMPDIR="${TMPDIR:-/tmp}"

# Create log directory if it doesn't exist
mkdir -p "$LOGDIR"

# Logging function
log_debug() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

# Find URL extraction tool
find_url_tool() {
    # Check for extract_url first (better URL detection)
    if command -v extract_url >/dev/null 2>&1; then
        echo "extract_url"
    elif command -v urlview >/dev/null 2>&1; then
        echo "urlview"
    else
        echo ""
    fi
}

# Main function
main() {
    log_debug "=== Starting tmux-urlview-wrapper ==="
    log_debug "PATH: $PATH"
    log_debug "TMPDIR: $TMPDIR"
    
    # Find URL extraction tool
    URL_TOOL=$(find_url_tool)
    log_debug "URL tool found: '$URL_TOOL'"
    
    if [ -z "$URL_TOOL" ]; then
        log_debug "ERROR: No URL extraction tool found"
        tmux display-message "❌ Error: Neither urlview nor extract_url found. Run: brew install extract_url"
        exit 1
    fi
    
    # Get full path of the tool
    URL_TOOL_PATH=$(command -v "$URL_TOOL")
    log_debug "URL tool path: $URL_TOOL_PATH"
    
    # Create temporary file with proper naming
    TMPFILE=$(mktemp "${TMPDIR}/tmux-urlview.XXXXXX")
    log_debug "Created temp file: $TMPFILE"
    
    # Capture pane content
    if ! tmux capture-pane -J -p > "$TMPFILE" 2>> "$LOGFILE"; then
        log_debug "ERROR: Failed to capture pane"
        tmux display-message "❌ Error: Failed to capture pane content"
        rm -f "$TMPFILE"
        exit 1
    fi
    
    # Check if file has content
    if [ ! -s "$TMPFILE" ]; then
        log_debug "WARNING: Captured file is empty"
        tmux display-message "⚠️  No content in current pane"
        rm -f "$TMPFILE"
        exit 0
    fi
    
    FILE_SIZE=$(wc -c < "$TMPFILE")
    LINE_COUNT=$(wc -l < "$TMPFILE")
    log_debug "Captured $LINE_COUNT lines, $FILE_SIZE bytes"
    
    # Set terminal dimensions for extract_url
    if [ "$URL_TOOL" = "extract_url" ]; then
        # Get tmux pane dimensions if available
        if [ -n "${TMUX:-}" ]; then
            export LINES=$(tmux display-message -p '#{pane_height}')
            export COLUMNS=$(tmux display-message -p '#{pane_width}')
            log_debug "Set terminal size from tmux: ${LINES}x${COLUMNS}"
        else
            # Fallback dimensions
            export LINES=24
            export COLUMNS=80
            log_debug "Using fallback terminal size: ${LINES}x${COLUMNS}"
        fi
    fi
    
    # Run the URL extraction tool
    log_debug "Running: $URL_TOOL_PATH $TMPFILE"
    
    # Run the tool and capture exit code
    set +e
    "$URL_TOOL_PATH" "$TMPFILE"
    EXIT_CODE=$?
    set -e
    
    log_debug "URL tool exited with code: $EXIT_CODE"
    
    # Clean up
    rm -f "$TMPFILE"
    log_debug "Cleaned up temp file"
    log_debug "=== Finished tmux-urlview-wrapper ==="
    
    return $EXIT_CODE
}

# Run main function with error handling
if ! main "$@"; then
    log_debug "Script exited with error"
    exit 1
fi