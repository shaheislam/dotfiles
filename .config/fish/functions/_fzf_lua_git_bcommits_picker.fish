# fzf-lua git buffer commits picker - select file then show its commit history
# Step 1: Select a file from git files (with scope switching support)
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

    # Step 1: Select a file from git files (with scope switching support)
    set -l scope "git"  # Default to git root
    set -l file ""

    while true
        # Build cwd and picker based on scope
        set -l cwd
        set -l picker "git_files"
        switch $scope
            case "local"
                set cwd (pwd)
            case "git"
                set cwd (git rev-parse --show-toplevel 2>/dev/null)
            case "global"
                set cwd $HOME
                set picker "files"  # Use files picker for global (not git-specific)
        end

        set -l result (_fzf_lua_cli $picker cwd="$cwd" prompt="Select file ($scope)❯ ")

        if test -z "$result"
            commandline -f repaint
            return 0
        end

        # Handle scope switching
        if string match -q "__scope__:*" -- $result
            set -l parts (string split ":" -- $result)
            set scope $parts[2]
            continue
        end

        # Got a file, break out
        set file $result
        break
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
