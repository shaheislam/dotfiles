# fzf-lua git diffview - toggle Diffview for working directory changes
# Opens Neovim with DiffviewOpen to show uncommitted changes

function _fzf_lua_git_diffview --description "Toggle Diffview - show working directory changes"
    # Check if we're in a git repository
    if not git rev-parse --is-inside-work-tree 2>/dev/null >/dev/null
        echo "Not in a git repository"
        commandline -f repaint
        return 1
    end

    nvim -c "DiffviewOpen"
    commandline -f repaint
end
