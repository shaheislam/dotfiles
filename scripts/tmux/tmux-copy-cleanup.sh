#!/usr/bin/env bash
# tmux-copy-cleanup.sh - Clean up copied text from tmux copy-mode
# Removes spurious line breaks caused by terminal soft-wrapping
# Used as a copy-pipe target in tmux for "clean copy" operations
#
# Usage in tmux:
#   bind-key -T copy-mode-vi Y send-keys -X copy-pipe 'tmux-copy-cleanup.sh'
#
# Mode: $1 (optional)
#   "join"       - Join all lines (default, best for commands)
#   "smart"      - Preserve paragraph breaks, join wrapped lines
#   "passthrough" - Just pass to clipboard (same as plain pbcopy)

set -euo pipefail

MODE="${1:-join}"

# Read stdin (text from tmux copy-pipe)
INPUT=$(cat)

case "$MODE" in
join)
    # Join all lines, collapse whitespace - ideal for commands
    printf '%s' "$INPUT" | tr '\n' ' ' | sed 's/  */ /g; s/^ *//; s/ *$//'
    ;;
smart)
    # Preserve paragraph breaks (double newlines), join single newlines
    printf '%s' "$INPUT" | awk '
            BEGIN { para = "" }
            /^[[:space:]]*$/ {
                if (para != "") { print para; print ""; para = "" }
                next
            }
            {
                sub(/[[:space:]]+$/, "")
                if (para == "") { para = $0 }
                else { para = para " " $0 }
            }
            END { if (para != "") print para }
        '
    ;;
passthrough)
    printf '%s' "$INPUT"
    ;;
esac | if [ "$(uname -s)" = "Darwin" ]; then
    pbcopy
else
    xclip -selection clipboard 2>/dev/null || xsel --clipboard --input 2>/dev/null || true
fi
