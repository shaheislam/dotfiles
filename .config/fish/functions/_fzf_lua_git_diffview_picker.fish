# fzf-lua git diffview picker - select commits to compare in Diffview
# Tab to select up to 2 commits, Enter to open in Diffview
# Single commit: compare to parent | Two commits: compare range

function _fzf_lua_git_diffview_picker --description "Select commits to compare in Diffview"
    # Check if we're in a git repository
    if not git rev-parse --is-inside-work-tree 2>/dev/null >/dev/null
        echo "Not in a git repository"
        commandline -f repaint
        return 1
    end

    # git_commits with multi-select - Tab to select, Enter when done
    set -l result (_fzf_lua_cli git_commits)

    if test -z "$result"
        commandline -f repaint
        return 0
    end

    # Parse selected commits (newline-separated)
    set -l commits (string split "\n" -- $result | string match -v "")
    set -l count (count $commits)

    if test $count -eq 1
        # Single commit - compare to its parent
        nvim -c "DiffviewOpen $commits[1]^..$commits[1]"
    else if test $count -ge 2
        # Two commits - first selected = base, second = target
        nvim -c "DiffviewOpen $commits[1]..$commits[2]"
    end

    commandline -f repaint
end
