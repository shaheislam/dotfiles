# fzf-lua git diffview picker - select commits then files to compare in Diffview
# Step 1: Tab to select up to 2 commits
# Step 2: Select files to compare (Tab=select, Ctrl-A=all, Esc=skip)
# Single commit: compare to parent | Two commits: compare range

function _fzf_lua_git_diffview_picker --description "Select commits to compare in Diffview"
    # Check if we're in a git repository
    if not git rev-parse --is-inside-work-tree 2>/dev/null >/dev/null
        echo "Not in a git repository"
        commandline -f repaint
        return 1
    end

    # Step 1: Select commits
    set -l result (_fzf_lua_cli git_commits)
    if test -z "$result"
        commandline -f repaint
        return 0
    end

    # Parse selected commits (newline-separated)
    set -l commits (string split "\n" -- $result | string match -v "")
    set -l count (count $commits)

    # Build range string and diff command
    set -l range
    set -l diff_cmd

    if test $count -eq 1
        set range "$commits[1]^..$commits[1]"
        set diff_cmd "git diff-tree --no-commit-id --name-only -r $commits[1]"
    else if test $count -ge 2
        set range "$commits[1]..$commits[2]"
        set diff_cmd "git diff --name-only $commits[1] $commits[2]"
    else
        commandline -f repaint
        return 0
    end

    # Step 2: File filter picker
    # Get changed files and show in fzf with multi-select
    # Ctrl-A = select all, Tab = toggle selection
    set -l files (eval $diff_cmd | fzf --multi \
        --prompt "Files (Tab=select, C-a=all)❯ " \
        --header "Enter: open selected | Esc: open all" \
        --bind "ctrl-a:select-all" \
        --preview "git diff $range -- {} | delta 2>/dev/null || git diff $range -- {}" \
        --preview-window "right:60%:wrap")

    # If no files selected (Esc pressed), use all files
    if test -z "$files"
        set files (eval $diff_cmd)
    end

    # Step 3: Open Diffview
    if test -n "$files"
        # Join files with spaces for Diffview command
        set -l file_args (printf '%s ' $files | string trim)
        nvim -c "DiffviewOpen $range -- $file_args"
    else
        nvim -c "DiffviewOpen $range"
    end

    commandline -f repaint
end
