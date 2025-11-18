function _git_fzf_tab_complete -d "Map git subcommands to fzf-git.sh commands on TAB"
    set -l cmd (commandline -opc)

    # Need at least "git subcommand" to determine which fzf command to use
    if test (count $cmd) -lt 2
        _fifc
        return
    end

    set -l git_subcommand $cmd[2]

    # Map git subcommands to fzf-git.sh commands
    switch $git_subcommand
        case add rm restore
            # File operations - show uncommitted/tracked files
            __fzf_git_sh files
        case branch checkout switch merge rebase
            # Branch operations
            __fzf_git_sh branches
        case log show diff cherry-pick revert
            # Commit operations
            __fzf_git_sh hashes
        case reset
            # Reset can be files or hashes depending on flags
            # Check if --hard, --soft, or --mixed is present
            if string match -qr -- '--hard|--soft|--mixed' (commandline -opc)
                __fzf_git_sh hashes
            else
                __fzf_git_sh files
            end
        case push pull fetch remote
            # Remote operations
            __fzf_git_sh remotes
        case stash
            # Stash operations
            __fzf_git_sh stashes
        case tag
            # Tag operations
            __fzf_git_sh tags
        case worktree
            # Worktree operations - fall back to FIFC for now
            # (fzf-git.sh has worktrees support but may need custom integration)
            _fifc
        case '*'
            # Fall back to FIFC for other git commands
            _fifc
    end
end
