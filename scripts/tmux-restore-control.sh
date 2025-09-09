#!/bin/bash
# Control tmux-continuum automatic restore

case "$1" in
    disable)
        tmux set -g @continuum-restore 'off'
        echo "✅ Automatic restore disabled"
        echo "   Restore manually with: tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
        ;;
    enable)
        tmux set -g @continuum-restore 'on'
        echo "✅ Automatic restore enabled"
        ;;
    status)
        STATUS=$(tmux show -gv @continuum-restore)
        echo "Automatic restore is: $STATUS"
        ;;
    *)
        echo "Usage: $0 {disable|enable|status}"
        echo ""
        echo "Disable automatic restore to prevent 1Password prompts on tmux start"
        echo "Then manually restore when ready to approve all connections at once"
        exit 1
        ;;
esac
