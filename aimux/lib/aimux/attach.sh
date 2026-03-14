#!/usr/bin/env bash
# aimux attach - attach to workspace

_attach_target="${1:-}"

if [[ "$_attach_target" == "-h" || "$_attach_target" == "--help" ]]; then
    echo "Usage: aimux attach [name]"
    echo "  Without name: fzf picker of all tmux windows"
    echo "  With name: switch to matching window"
    exit 0
fi

require tmux

if [[ -z "$_attach_target" ]]; then
    # FZF picker
    if has fzf; then
        _selection=$(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name} #{pane_current_path}' 2>/dev/null |
            fzf --prompt="Attach to: " --height=40% --reverse |
            cut -d' ' -f1 || true)
        [[ -z "$_selection" ]] && exit 0
        if in_tmux; then
            tmux switch-client -t "$_selection" 2>/dev/null
        else
            tmux attach-session -t "$_selection"
        fi
    else
        die "Usage: aimux attach <name> (or install fzf for interactive picker)"
    fi
else
    if in_tmux; then
        session="$(tmux_session)"
        # Find window by name in current session
        window=$(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null |
            grep ":${_attach_target}" | head -1 | cut -d: -f1 || true)
        if [[ -n "$window" ]]; then
            tmux select-window -t "$session:$window"
        else
            # Search all sessions
            match=$(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}' 2>/dev/null |
                grep "$_attach_target" | head -1 | cut -d' ' -f1 || true)
            if [[ -n "$match" ]]; then
                tmux switch-client -t "$match"
            else
                die "No workspace found matching: $_attach_target"
            fi
        fi
    else
        tmux attach-session -t "$_attach_target" 2>/dev/null || die "No session found: $_attach_target"
    fi
fi
