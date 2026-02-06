function gwt-claude --description "Launch Claude Code in worktree devcontainer"
    # Usage: gwt-claude [branch-name]
    #
    # Launches Claude Code inside the devcontainer associated with a worktree.
    # If no branch is specified, uses fzf to select from available worktrees.
    #
    # Options:
    #   --help, -h    Show this help

    if test "$argv[1]" = "--help"; or test "$argv[1]" = "-h"
        echo "Usage: gwt-claude [branch-name]"
        echo ""
        echo "Launch Claude Code in a worktree's devcontainer."
        echo ""
        echo "If no branch is specified, an fzf picker shows available worktrees."
        echo "The devcontainer must already be running or will be started."
        echo ""
        echo "Examples:"
        echo "  gwt-claude                  # Pick worktree with fzf"
        echo "  gwt-claude feature/auth     # Specific worktree"
        return 0
    end

    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    set -l repo (basename (git rev-parse --show-toplevel))
    set -l branch $argv[1]
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
            echo "Cancelled"
            return 0
        end

        set worktree_path (echo $selected | awk '{print $1}')
        set -l worktree_name (basename $worktree_path)
        set instance_name (string replace -a "/" "-" $worktree_name)
    else
        # Construct worktree path from branch
        set -l worktree_name "$repo-$branch"
        set worktree_path (git rev-parse --show-toplevel)/../$worktree_name
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

    if $instance_running
        echo "Container running, exec into claude..."
        # Execute claude in the running container
        devcon claude -i $instance_name --exec
    else
        echo "Starting devcontainer..."
        # Start the devcontainer with the worktree mounted
        devcon claude -i $instance_name $worktree_path --exec
    end
end
