function gwtl --description "List git worktrees or switch to one with fzf"
    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Not in a git repository"
        return 1
    end

    set -l worktrees (git worktree list 2>/dev/null)

    if test -z "$worktrees"
        echo "No git worktrees found"
        return 1
    end

    # If stdout is a terminal, use fzf for selection
    if isatty stdout
        set -l selected (printf '%s\n' $worktrees | fzf --height=40% --reverse --prompt="Switch to worktree: " | awk '{print $1}')
        if test -n "$selected"
            cd "$selected"
            echo "Switched to: $selected"
        end
    else
        # Non-interactive mode, just list
        printf '%s\n' $worktrees
    end
end
