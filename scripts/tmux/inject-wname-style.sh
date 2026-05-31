#!/usr/bin/env bash
# Inject @wname_style into window-status-format for agent coloring,
# and fix overflow marker styling for Tokyo Night theme consistency.
# Run after TPM/powerkit generates the format strings. PowerKit reloads
# asynchronously, so retry briefly to survive a late repaint of #W.
#
# When @wname_style is set on a window (by tmux-claude-watcher.sh),
# it overrides the text color of the window name in the status bar.
# When unset, the format falls through to the default powerkit colors.

inject() {
    local opt=$1
    local fmt
    fmt=$(tmux show-option -gqv "$opt" 2>/dev/null) || return
    [[ -z "$fmt" ]] && return
    # Already patched
    [[ "$fmt" == *"@wname_style"* ]] && return

    # \#W needed — bash interprets # specially in pattern expansion
    local repl='#{?#{@wname_style},#{@wname_style},}#W'
    local patched="${fmt/\#W/$repl}"

    [[ "$patched" != "$fmt" ]] && tmux set-option -g "$opt" "$patched"
}

# Fix overflow markers: powerkit generates plain < > with off-palette colors.
# Replace with Tokyo Night dim (#565f89) styled markers.
fix_markers() {
    local fmt
    fmt=$(tmux show-option -gqv "status-format[0]" 2>/dev/null) || return
    [[ -z "$fmt" ]] && return
    # Skip if already patched or no markers to fix
    [[ "$fmt" != *'left-marker]<'* ]] && return

    # Embed fg override inside marker content so color is correct
    # regardless of the surrounding style context.
    local patched="${fmt/'left-marker]<'/'left-marker]#[fg=#565f89]<'}"
    patched="${patched/'right-marker]>'/'right-marker]#[fg=#565f89]>'}"

    [[ "$patched" != "$fmt" ]] && tmux set-option -g "status-format[0]" "$patched"
}

inject_all() {
    inject window-status-format
    inject window-status-current-format
    fix_markers
}

for _ in 1 2 3 4 5; do
    inject_all
    sleep 0.25
done
