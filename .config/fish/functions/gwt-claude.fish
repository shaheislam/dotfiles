function gwt-claude --description "Launch Claude Code in worktree devcontainer"
    # Usage: gwt-claude [branch-name] [options]
    #
    # Launches Claude Code inside the devcontainer associated with a worktree.
    # If no branch is specified, uses fzf to select from available worktrees.
    #
    # Options:
    #   --sub NAME    Claude subscription profile (uses ~/.claude-NAME config dir)
    #   --help, -h    Show this help

    if test "$argv[1]" = --help; or test "$argv[1]" = -h
        echo "Usage: gwt-claude [branch-name] [options]"
        echo ""
        echo "Launch Claude Code in a worktree's devcontainer."
        echo ""
        echo "If no branch is specified, an fzf picker shows available worktrees."
        echo "The devcontainer must already be running or will be started."
        echo ""
        echo "Options:"
        echo "  --sub NAME    Claude subscription profile (uses ~/.claude-NAME config dir)"
        echo ""
        echo "Examples:"
        echo "  gwt-claude                          # Pick worktree with fzf"
        echo "  gwt-claude feature/auth             # Specific worktree"
        echo "  gwt-claude feature/auth --sub work  # Specific subscription"
        return 0
    end

    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    # Parse arguments - extract --sub flag and branch name
    set -l sub_profile ""
    set -l branch ""
    set -l skip_next false

    for i in (seq (count $argv))
        if $skip_next
            set skip_next false
            continue
        end
        set -l arg $argv[$i]
        switch $arg
            case --sub
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set sub_profile $argv[$next_i]
                    set -l config_dir "$HOME/.claude-$sub_profile"
                    if not test -d "$config_dir"
                        echo "Error: Profile '$sub_profile' not found ($config_dir)"
                        echo "Run: claude-sub setup $sub_profile"
                        return 1
                    end
                    set skip_next true
                else
                    echo "Error: --sub requires a profile name (e.g., work, personal)"
                    return 1
                end
            case '*'
                if test -z "$branch"
                    set branch $arg
                end
        end
    end

    # Resolve to main repo root (not worktree root)
    set -l git_common_dir (git rev-parse --git-common-dir)
    set -l repo_root (realpath "$git_common_dir/..")
    set -l repo (basename $repo_root)
    set -l worktree_path ""
    set -l instance_name ""

    if test -z "$branch"
        # Use fzf to select worktree
        set -l worktrees (git worktree list 2>/dev/null)

        if test -z "$worktrees"
            echo "No worktrees found"
            return 1
        end

        set -l selected (printf '%s\n' $worktrees | fzf --height=40% --reverse --prompt="Select worktree for Claude: ")

        if test -z "$selected"
            echo Cancelled
            return 0
        end

        set worktree_path (echo $selected | awk '{print $1}')
        set -l worktree_name (basename $worktree_path)
        set instance_name (string replace -a "/" "-" $worktree_name)
    else
        # Construct worktree path from branch
        set -l worktree_name "$repo-$branch"
        set worktree_path "$repo_root/../$worktree_name"
        set instance_name (string replace -a "/" "-" $worktree_name)

        # Verify worktree exists
        if not test -d "$worktree_path"
            echo "Error: Worktree not found: $worktree_path"
            echo ""
            echo "Available worktrees:"
            git worktree list
            echo ""
            echo "Tip: Use 'gwt-dev $branch' to create the worktree first"
            return 1
        end
    end

    set worktree_path (realpath $worktree_path)
    echo "Worktree: $worktree_path"
    echo "Instance: $instance_name"

    set -l manifest_script "$repo_root/scripts/workspace-manifest.sh"
    if test -x "$manifest_script"
        set -l manifest_output ($manifest_script info --worktree "$worktree_path" 2>/dev/null)
        if test -n "$manifest_output"
            echo "Workspace manifest summary:"
            for line in $manifest_output
                echo "  $line"
            end
        end
    end

    # Always use the built-in devcon claude sandbox for isolation.
    # The devcon function uses ~/dotfiles/devcontainer/claude-code-plugins/
    # so the project does NOT need its own .devcontainer/ directory.

    # Check if devcontainer instance exists and is running
    set -l instance_base "$HOME/.devcontainer/instances"
    set -l instance_running false

    if command -q docker
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "$instance_name"
            set instance_running true
        end
    end

    # Build devcon env flags for subscription profile
    set -l sub_env_flags
    if test -n "$sub_profile"
        set sub_env_flags -E "CLAUDE_CONFIG_DIR=/home/node/.claude-$sub_profile"
        echo "Sub:       $sub_profile (~/.claude-$sub_profile)"
    end

    if $instance_running
        echo "Container running, exec into claude..."
        # Execute claude in the running container
        devcon claude -i $instance_name $sub_env_flags --exec
    else
        echo "Starting devcontainer..."
        # Start the devcontainer with the worktree mounted
        devcon claude -i $instance_name $sub_env_flags $worktree_path --exec
    end
end
