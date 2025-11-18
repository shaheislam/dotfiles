function _git_fzf_tab_complete -d "Map git subcommands to fzf-git.sh commands on TAB"
    # Ensure we don't interfere with Git operations - handle errors gracefully
    set -l cmd (commandline -opc) 2>/dev/null

    # Need at least "git subcommand" to determine which fzf command to use
    if test (count $cmd) -lt 2
        _fifc 2>/dev/null || complete
        return
    end

    set -l git_subcommand $cmd[2]

    # Map git subcommands to fzf-git.sh commands
    switch $git_subcommand
        case add rm restore
            # File operations - show uncommitted/tracked files
            __fzf_git_sh files 2>/dev/null || _fifc 2>/dev/null || complete
        case branch checkout switch merge rebase
            # Branch operations
            __fzf_git_sh branches 2>/dev/null || _fifc 2>/dev/null || complete
        case log show diff cherry-pick revert
            # Commit operations
            __fzf_git_sh hashes 2>/dev/null || _fifc 2>/dev/null || complete
        case reset
            # Reset can be files or hashes depending on flags
            # Check if --hard, --soft, or --mixed is present
            if string match -qr -- '--hard|--soft|--mixed' (commandline -opc)
                __fzf_git_sh hashes 2>/dev/null || _fifc 2>/dev/null || complete
            else
                __fzf_git_sh files 2>/dev/null || _fifc 2>/dev/null || complete
            end
        case push pull fetch
            # Context-aware routing: remotes first, then branches
            if test (count $cmd) -ge 3
                # Already have remote, show branches
                __fzf_git_sh branches 2>/dev/null || _fifc 2>/dev/null || complete
            else
                # Need to select remote first
                __fzf_git_sh remotes 2>/dev/null || _fifc 2>/dev/null || complete
            end
        case remote
            # Remote management operations
            __fzf_git_sh remotes 2>/dev/null || _fifc 2>/dev/null || complete
        case stash
            # Stash operations
            __fzf_git_sh stashes 2>/dev/null || _fifc 2>/dev/null || complete
        case tag
            # Tag operations
            __fzf_git_sh tags 2>/dev/null || _fifc 2>/dev/null || complete
        case worktree
            # Worktree operations - fall back to FIFC for now
            # (fzf-git.sh has worktrees support but may need custom integration)
            _fifc 2>/dev/null || complete
        case '*'
            # Fall back to FIFC for other git commands
            _fifc 2>/dev/null || complete
    end
end