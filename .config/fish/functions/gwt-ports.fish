function gwt-ports --description "Manage per-worktree port allocations"
    # Usage: gwt-ports [allocate|release|get|list|cleanup|env] [worktree-name]
    #
    # Prevents port conflicts when running multiple worktree devcontainers.
    # Each worktree gets a range of 20 consecutive ports from a base port.
    #
    # Inspired by superset-sh/superset's port allocation system.

    set -l script_dir (status dirname 2>/dev/null; or echo (dirname (status filename)))
    set -l allocator "$HOME/dotfiles/scripts/port-allocator.sh"

    if not test -f "$allocator"
        echo "Error: port-allocator.sh not found at $allocator"
        return 1
    end

    if test (count $argv) -eq 0
        bash "$allocator"
        return $status
    end

    set -l cmd $argv[1]
    set -l rest $argv[2..]

    switch $cmd
        case allocate release get env
            # These need a worktree name; auto-detect from current directory if not given
            if test (count $rest) -eq 0
                # Try to derive worktree name from current git context
                set -l git_common_dir (git rev-parse --git-common-dir 2>/dev/null)
                or begin
                    echo "Error: Not in a git repo and no worktree name given"
                    return 1
                end
                set -l repo_root (realpath "$git_common_dir/..")
                set -l repo (basename $repo_root)
                set -l branch (git branch --show-current 2>/dev/null)
                or begin
                    echo "Error: Could not determine branch"
                    return 1
                end
                set -l wt_name (string replace -a "/" "-" "$repo-$branch")
                bash "$allocator" $cmd $wt_name
            else
                bash "$allocator" $cmd $rest[1]
            end
        case list cleanup
            bash "$allocator" $cmd
        case '*'
            bash "$allocator" $argv
    end
    return $status
end
