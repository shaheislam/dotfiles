# fzf-lua git merge - open Diffview merge conflicts view
# Opens Neovim with DiffviewOpen focused on merge conflicts

function _fzf_lua_git_merge --description "Open Diffview merge conflicts view"
    # Check if we're in a git repository
    if not git rev-parse --is-inside-work-tree 2>/dev/null >/dev/null
        echo "Not in a git repository"
        commandline -f repaint
        return 1
    end

    # Check if there are actual merge conflicts
    set -l conflicts (git diff --name-only --diff-filter=U 2>/dev/null)
    if test -z "$conflicts"
        echo "No merge conflicts found"
        commandline -f repaint
        return 0
    end

    nvim -c "DiffviewOpen"
    commandline -f repaint
end
