set -g __git_fzf_functions_dir (status dirname)

function __git_fzf_load_helper --description "Load fzf-git helper on demand"
    if functions -q __fzf_git_sh
        return 0
    end

    set -l helper "$__git_fzf_functions_dir/fzf-git.fish"
    if not test -f "$helper"
        set helper "$HOME/.config/fish/functions/fzf-git.fish"
    end

    if test -f "$helper"
        source "$helper"
    end

    functions -q __fzf_git_sh
end

function __git_fzf_or_fifc --description "Run fzf-git helper, then fall back quietly"
    if __git_fzf_load_helper
        __fzf_git_sh $argv 2>/dev/null; and return 0
    end

    _fifc 2>/dev/null
end

function __git_fzf_or_return --description "Run fzf-git helper without surfacing failure"
    if __git_fzf_load_helper
        __fzf_git_sh $argv 2>/dev/null; and return 0
    end

    return 0
end

function _git_fzf_tab_complete -d "Map git subcommands to fzf-git.sh commands on TAB"
    # Ensure we don't interfere with Git operations - handle errors gracefully
    set -l cmd (commandline -opc) 2>/dev/null

    # Need at least "git subcommand" to determine which fzf command to use
    if test (count $cmd) -lt 2
        _fifc 2>/dev/null
        return
    end

    set -l git_subcommand $cmd[2]

    # Map git subcommands to fzf-git.sh commands
    switch $git_subcommand
        case add rm restore
            # File operations - show uncommitted/tracked files
            __git_fzf_or_fifc files
        case branch merge rebase
            # Branch operations
            __git_fzf_or_fifc branches
        case checkout switch
            # Context-aware checkout: files after --, branches otherwise
            if contains -- '--' $cmd
                __git_fzf_or_fifc files
            else
                __git_fzf_or_fifc branches
            end
        case log
            # Context-aware log: files after --, hashes otherwise
            if contains -- '--' $cmd
                __git_fzf_or_fifc files
            else
                __git_fzf_or_fifc hashes
            end
        case diff
            # Context-aware diff: files after --, hashes otherwise
            if contains -- '--' $cmd
                __git_fzf_or_fifc files
            else
                __git_fzf_or_fifc hashes
            end
        case cherry-pick revert
            # Commit operations
            __git_fzf_or_fifc hashes
        case difftool
            # Use standard fzf-git hashes picker (has C-b to switch to branches)
            __git_fzf_or_fifc hashes
        case show
            # Context-aware show: files with --stat/--name-only, commits otherwise
            if string match -qr -- '--stat|--name-only' (commandline -opc)
                __git_fzf_or_fifc files
            else
                __git_fzf_or_fifc hashes
            end
        case commit
            # Context-aware commit: hashes for --fixup, normal completion otherwise
            if string match -qr -- '--fixup' (commandline -opc)
                __git_fzf_or_fifc hashes
            else
                _fifc 2>/dev/null
            end
        case reflog
            # Reflog operations - show reflog entries
            __git_fzf_or_fifc lreflogs
        case bisect
            # Bisect operations - show commits for start/good/bad
            __git_fzf_or_fifc hashes
        case blame
            # Blame operations - show files to blame
            __git_fzf_or_fifc files
        case cherry
            # Cherry operations - show branches for comparison
            __git_fzf_or_fifc branches
        case merge-base
            # If currently typing a flag, use standard completion for flags
            set -l current_token (commandline --current-token)
            if string match -qr -- '^-' "$current_token"
                _fifc 2>/dev/null
                return
            end

            # Context-aware merge-base: commits first, then branches for --is-ancestor
            if string match -qr -- '--is-ancestor' (commandline -opc)
                # Count non-flag arguments after the subcommand
                set -l mb_args
                for arg in $cmd[3..-1]
                    if not string match -qr -- '^-' $arg
                        set -a mb_args $arg
                    end
                end

                if test (count $mb_args) -eq 0
                    # First arg: show commits (hashes)
                    __git_fzf_or_fifc hashes
                else if test (count $mb_args) -eq 1
                    # Second arg: show branches
                    __git_fzf_or_fifc branches
                else
                    # Both provided: fall back to normal completion
                    _fifc 2>/dev/null
                end
            else
                # Without --is-ancestor: show commits and branches
                __git_fzf_or_fifc hashes
            end
        case clean
            # Show untracked files for git clean
            set -l untracked (git clean -n -d 2>/dev/null | sed 's/^Would remove //')
            if test -n "$untracked"
                set -l selected (printf '%s\n' $untracked | fzf --multi --preview="test -d {} && tree -C {} 2>/dev/null || bat --color=always {} 2>/dev/null || cat {}")
                if test -n "$selected"
                    commandline -i (string join ' ' $selected)
                end
            else
                _fifc 2>/dev/null
            end
        case reset
            # Reset can be files or hashes depending on flags
            # Check if --hard, --soft, or --mixed is present
            if string match -qr -- '--hard|--soft|--mixed' (commandline -opc)
                __git_fzf_or_fifc hashes
            else
                __git_fzf_or_fifc files
            end
        case push
            # Context-aware push: remotes first, then branches, then flags
            # Count non-flag arguments to determine position
            set -l push_args
            for arg in $cmd[3..-1]
                if not string match -qr -- '^-' $arg
                    set -a push_args $arg
                end
            end

            if test (count $push_args) -eq 0
                # No remote yet: show remotes
                __git_fzf_or_fifc remotes
            else if test (count $push_args) -eq 1
                # Have remote, need branch: show branch picker
                __git_fzf_or_fifc branches
            else
                # Have both remote and branch: show normal completions (flags)
                _fifc 2>/dev/null
            end
        case pull fetch
            # Context-aware routing: remotes first, then branches
            if test (count $cmd) -ge 3
                # Already have remote, show branches
                __git_fzf_or_fifc branches
            else
                # Need to select remote first
                __git_fzf_or_fifc remotes
            end
        case remote
            # Remote management operations
            __git_fzf_or_fifc remotes
        case stash
            # Context-aware stash: show files for push, stashes for other operations
            set -l stash_subcmd
            if test (count $cmd) -ge 3
                set stash_subcmd $cmd[3]
            end
            if test "$stash_subcmd" = "push"
                # Show modified files to select for stashing
                __git_fzf_or_fifc files
            else
                # Default: show stashes
                __git_fzf_or_fifc stashes
            end
        case tag
            # Tag operations
            __git_fzf_or_fifc tags
        case worktree
            # Context-aware worktree completion
            set -l worktree_cmd (commandline -opc)

            # At position 2 (git worktree <TAB>), show subcommands via native completion
            if test (count $worktree_cmd) -eq 2
                _fifc 2>/dev/null || return
                return
            end

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
                            __git_fzf_or_return branches
                        else
                            # Branch name provided: auto-suggest path
                            set -l repo (basename (git rev-parse --show-toplevel 2>/dev/null) 2>/dev/null)
                            if test -n "$repo"
                                # Suggest default path pattern and return
                                # Next TAB will trigger branch selection
                                commandline --current-token --replace "../$repo-$branch_flag_value "
                                return
                            end
                            # Fallback if repo detection fails
                            return
                        end
                    else if test $arg_count -ge 1
                        # Path provided: select base branch with fzf
                        __git_fzf_or_return branches
                    end
                else
                    # git worktree add [path] [existing-branch]
                    if test $arg_count -eq 0
                        # No args yet: show branch picker, then auto-fill path
                        set -l fzf_git_sh_path (realpath (status dirname))
                        set -l current_token (commandline --current-token)
                        # Don't use -- as query (it breaks grep in fzf-git.sh)
                        set -l query "$current_token"
                        if test "$current_token" = "--"
                            set query ""
                        end
                        set -l selected_branch (FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --query='$query'" SHELL=bash bash "$fzf_git_sh_path/fzf-git.sh" --run branches 2>/dev/null | string trim)

                        if test -n "$selected_branch"
                            # Branch selected: auto-fill path pattern
                            set -l repo (basename (git rev-parse --show-toplevel 2>/dev/null) 2>/dev/null)
                            if test -n "$repo"
                                commandline --current-token --replace "../$repo-$selected_branch "
                                return
                            end
                        end
                        # Fallback gracefully if fzf cancelled or repo detection failed
                        return
                    else if test $arg_count -eq 1
                        # Path provided, need branch: show branch picker
                        __git_fzf_or_return branches
                    else if test $arg_count -ge 2
                        # Both path and branch provided: complete
                        return
                    end
                end
            else
                # Other worktree operations: show existing worktrees
                __git_fzf_or_fifc worktrees
            end
        case '*'
            # Fall back to FIFC for other git commands
            _fifc 2>/dev/null
    end
end
