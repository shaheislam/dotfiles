# fzf-lua git buffer commits picker - select file then show its commit history
# Step 1: Select a file from git files (using fzf-lua)
# Step 2: Show commits that modified that file (using native git + fzf)
# Output: Commit SHA
#
# Note: Cannot use fzf-lua git_bcommits - it requires Neovim buffer context

function _fzf_lua_git_bcommits_picker --description "Select file then show its commit history"
    # Check if we're in a git repository
    if not git rev-parse --is-inside-work-tree 2>/dev/null >/dev/null
        echo "Not in a git repository"
        commandline -f repaint
        return 1
    end

    # Step 1: Select a file from git files (using fzf-lua)
    set -l file (_fzf_lua_cli git_files prompt="Select file for history❯ ")
    if test -z "$file"
        commandline -f repaint
        return 0
    end

    # Step 2: Show commits for that file using native git + fzf
    # (Cannot use fzf-lua git_bcommits - requires Neovim buffer context)
    set -l sha (git log --oneline --follow -- "$file" | \
        fzf --prompt "Commits for "(basename $file)"❯ " \
            --header "Enter: output SHA | C-y: copy SHA" \
            --preview "git show {1} --color=always | delta 2>/dev/null || git show {1} --color=always" \
            --preview-window "right:60%:wrap" \
            --bind "ctrl-y:execute-silent(echo {1} | pbcopy)+abort" | \
        awk '{print $1}')

    if test -n "$sha"
        echo $sha  # Output SHA
    end

    commandline -f repaint
end
