function tmux-worktree-on-exit --on-event fish_exit --description "Auto-cleanup worktree when closing tmux window via exit/Ctrl-D"
    # Only run inside tmux
    if test -z "$TMUX"
        return
    end

    # Only act if this is the last pane in the window
    set -l pane_count (tmux display-message -p '#{window_panes}' 2>/dev/null)
    if test "$pane_count" != "1"
        return
    end

    # Get session and window info
    set -l session_name (tmux display-message -p '#{session_name}' 2>/dev/null)
    set -l window_name (tmux display-message -p '#{window_name}' 2>/dev/null)

    if test -z "$session_name" -o -z "$window_name"
        return
    end

    # Run cleanup asynchronously (don't block shell exit)
    # The cleanup script handles all safety checks (session matching, branch protection, etc.)
    ~/dotfiles/scripts/tmux/tmux-worktree-cleanup.sh "$session_name" "$window_name" &
    disown 2>/dev/null
end
