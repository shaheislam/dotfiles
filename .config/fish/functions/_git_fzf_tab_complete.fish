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
            # Context-aware worktree completion
            set -l worktree_cmd (commandline -opc)

            # Check if 'add' subcommand is present
            if contains -- add $worktree_cmd
                # Parse arguments to determine position
                set -l has_branch_flag false
                set -l branch_flag_value ""
                set -l non_flag_args
                set -l i 4  # Start after 'git worktree add' (index 4 onwards)

                while test $i -le (count $worktree_cmd)
                    set -l arg $worktree_cmd[$i]

                    if test "$arg" = "-b"; or test "$arg" = "-B"
                        set has_branch_flag true
                        # Next arg should be the new branch name
                        set i (math $i + 1)
                        if test $i -le (count $worktree_cmd)
                            set branch_flag_value $worktree_cmd[$i]
                        end
                    else if not string match -qr -- '^-' $arg
                        # Non-flag argument
                        set -a non_flag_args $arg
                    end

                    set i (math $i + 1)
                end

                set -l arg_count (count $non_flag_args)

                # Position-based routing
                if test $has_branch_flag = true
                    # git worktree add -b <new-branch> [path] [base-branch]
                    if test $arg_count -eq 0
                        # Check if branch name provided yet
                        if test -z "$branch_flag_value"
                            # Show existing branches as reference/hints
                            __fzf_git_sh branches 2>/dev/null || complete
                        else
                            # Branch name provided: auto-suggest path
                            set -l repo (basename (git rev-parse --show-toplevel 2>/dev/null) 2>/dev/null)
                            if test -n "$repo"
                                # Suggest default path pattern and return
                                # Next TAB will trigger branch selection
                                commandline --current-token --replace "../$repo-$branch_flag_value"
                                return
                            end
                            # Fallback if repo detection fails
                            complete
                        end
                    else if test $arg_count -ge 1
                        # Path provided: select base branch with fzf
                        __fzf_git_sh branches 2>/dev/null || complete
                    end
                else
                    # git worktree add [path] [existing-branch]
                    if test $arg_count -eq 0
                        # No args yet: show branch picker, then auto-fill path
                        set -l fzf_git_sh_path (realpath (status dirname))
                        set -l selected_branch (SHELL=bash bash "$fzf_git_sh_path/fzf-git.sh" --run branches 2>/dev/null | string trim)

                        if test -n "$selected_branch"
                            # Branch selected: auto-fill path pattern
                            set -l repo (basename (git rev-parse --show-toplevel 2>/dev/null) 2>/dev/null)
                            if test -n "$repo"
                                commandline --current-token --replace "../$repo-$selected_branch "
                                return
                            end
                        end
                        # Fallback to native completion if fzf cancelled or repo detection failed
                        complete
                    else if test $arg_count -eq 1
                        # Path provided, need branch: show branch picker
                        __fzf_git_sh branches 2>/dev/null || complete
                    else if test $arg_count -ge 2
                        # Both path and branch provided: complete
                        return
                    end
                end
            else
                # Other worktree operations: show existing worktrees
                __fzf_git_sh worktrees 2>/dev/null || _fifc 2>/dev/null || complete
            end
        case '*'
            # Fall back to FIFC for other git commands
            _fifc 2>/dev/null || complete
    end
end