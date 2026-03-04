#!/usr/bin/env bash
# Inject @wname_style into window-status-format for agent coloring.
# Run after TPM/powerkit generates the format strings.
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

inject window-status-format
inject window-status-current-format
