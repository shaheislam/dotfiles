# fzf-lua git conflicts - find and open conflict files
# Uses FZF to select conflict files, then opens in nvim

function _fzf_lua_git_conflicts --description "Find git conflicts via FZF and open in nvim"
    # Check if we're in a git repository
    if not git rev-parse --is-inside-work-tree 2>/dev/null >/dev/null
        echo "Not in a git repository"
        commandline -f repaint
        return 1
    end

    # Get files with merge conflicts (unmerged paths)
    set -l conflicts (git diff --name-only --diff-filter=U 2>/dev/null)
    if test -z "$conflicts"
        echo "No merge conflicts found"
        commandline -f repaint
        return 0
    end

    # Use FZF to select conflict files
    set -l selected (
        printf '%s\n' $conflicts | \
        fzf --ansi \
            --multi \
            --bind 'tab:toggle+down,shift-tab:toggle+up' \
            --border-label="⚠️  Git Conflicts" \
            --header="TAB (multi-select) | ENTER (open in nvim) | CTRL-/ (preview)" \
            --preview="git diff --color=always -- {} 2>/dev/null | head -200" \
            --preview-window="right:60%:wrap" \
            --bind="ctrl-/:toggle-preview"
    )

    if test -n "$selected"
        # Open selected files in nvim
        set -l files (string split \n -- $selected)
        if test (count $files) -gt 0
            nvim $files
        end
    end
    commandline -f repaint
end
