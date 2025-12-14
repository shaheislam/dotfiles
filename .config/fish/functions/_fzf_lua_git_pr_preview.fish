# fzf-lua PR preview - compare current branch to base in Diffview
# Auto-detects available base branches (main, master, develop, etc.)
# Opens Neovim with DiffviewOpen base...HEAD

function _fzf_lua_git_pr_preview --description "PR preview - compare to base branch in Diffview"
    # Find available base branches (same logic as Neovim)
    set -l candidates origin/main origin/master origin/develop origin/dev origin/staging origin/production origin/prod origin/release origin/trunk
    set -l available

    for branch in $candidates
        if git rev-parse --verify $branch 2>/dev/null >/dev/null
            set -a available $branch
        end
    end

    if test (count $available) -eq 0
        echo "No base branches found (main/master/develop/staging)"
        return 1
    else if test (count $available) -eq 1
        # Single base - open directly
        nvim -c "DiffviewOpen $available[1]...HEAD"
    else
        # Multiple bases - use fzf to select
        set -l base (printf '%s\n' $available | fzf --prompt="Compare against: ")
        if test -n "$base"
            nvim -c "DiffviewOpen $base...HEAD"
        end
    end
    commandline -f repaint
end
