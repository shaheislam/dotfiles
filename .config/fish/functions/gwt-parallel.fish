function gwt-parallel --description "Launch multiple worktree devcontainers in tmux windows"
    # Usage: gwt-parallel <branch1> <branch2> [branch3] ... [--mount <dir>]
    #
    # Creates tmux windows in the current session for each specified worktree,
    # launching their devcontainers for parallel development.
    #
    # Each window is named after the branch for easy navigation.
    #
    # Options:
    #   --mount, -m   Add directory mount to all containers (repeatable)
    #   --no-devcon   Create windows and cd to worktrees without devcontainer
    #   --help, -h    Show this help

    if test "$argv[1]" = "--help"; or test "$argv[1]" = "-h"
        echo "Usage: gwt-parallel <branch1> <branch2> ... [--mount <dir>]"
        echo ""
        echo "Launch multiple worktrees in parallel tmux windows."
        echo ""
        echo "Options:"
        echo "  --mount, -m    Add directory mount to all containers (repeatable)"
        echo "  --no-devcon    Create windows without starting devcontainers"
        echo "  --help, -h     Show this help"
        echo ""
        echo "Examples:"
        echo "  gwt-parallel feature-a feature-b hotfix"
        echo "  gwt-parallel feature-a feature-b -m ~/dotfiles"
        echo "  gwt-parallel feat-a feat-b -m ~/dotfiles -m ~/reference"
        echo ""
        echo "Navigation:"
        echo "  prefix + n/p       Next/previous window"
        echo "  prefix + <number>  Jump to window by number"
        echo "  prefix + w         Window list"
        return 0
    end

    # Check we're in tmux
    if test -z "$TMUX"
        echo "Error: Not running inside tmux"
        echo ""
        echo "Start tmux first or use individual gwt-claude commands"
        return 1
    end

    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    # Parse arguments
    set -l branches
    set -l mounts
    set -l do_no_devcon false
    set -l skip_next false

    for i in (seq (count $argv))
        if $skip_next
            set skip_next false
            continue
        end

        set -l arg $argv[$i]

        switch $arg
            case --no-devcon
                set do_no_devcon true
            case --mount -m
                # Next arg is directory to mount
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set -l mount_path $argv[$next_i]
                    set -l expanded_path (eval echo $mount_path)
                    if test -d "$expanded_path"
                        set -a mounts (realpath $expanded_path)
                    else
                        echo "Error: Mount directory not found: $mount_path"
                        return 1
                    end
                    set skip_next true
                else
                    echo "Error: --mount requires a directory path"
                    return 1
                end
            case '-*'
                echo "Error: Unknown option: $arg"
                return 1
            case '*'
                set -a branches $arg
        end
    end

    if test (count $branches) -lt 1
        echo "Error: At least one branch name required"
        echo "Usage: gwt-parallel <branch1> <branch2> ..."
        return 1
    end

    set -l repo (basename (git rev-parse --show-toplevel))
    set -l repo_root (git rev-parse --show-toplevel)

    echo "Launching "(count $branches)" worktrees in parallel..."
    if test (count $mounts) -gt 0
        echo "Additional mounts for all containers:"
        for mount in $mounts
            echo "   /mounts/"(basename $mount)
        end
    end
    echo ""

    set -l created_windows
    set -l failed_branches

    for branch in $branches
        set -l worktree_name "$repo-$branch"
        set -l worktree_path "$repo_root/../$worktree_name"
        set -l instance_name (string replace -a "/" "-" $worktree_name)
        set -l window_name (string replace -a "/" "-" $branch)

        # Check if worktree exists
        if not test -d "$worktree_path"
            echo "Worktree not found: $branch"
            echo "    Creating with gwt-dev..."
            gwt-dev $branch --no-devcon
            if test $status -ne 0
                echo "   Failed to create worktree for $branch"
                set -a failed_branches $branch
                continue
            end
        end

        set worktree_path (realpath $worktree_path)

        # Create new tmux window
        echo "Creating window: $window_name"

        if $do_no_devcon
            # Just cd to worktree
            tmux new-window -n $window_name -c $worktree_path
        else
            # Check for devcontainer
            set -l has_devcontainer false
            if test -d "$worktree_path/.devcontainer"; or test -f "$worktree_path/devcontainer.json"
                set has_devcontainer true
            end

            if $has_devcontainer
                # Build mount arguments for devcon
                set -l mount_args ""
                for mount in $mounts
                    set mount_args "$mount_args $mount"
                end

                # Create window and run devcon in it
                tmux new-window -n $window_name -c $worktree_path \
                    "fish -c 'devcon claude -i $instance_name $worktree_path$mount_args --exec; exec fish'"
            else
                # No devcontainer, just cd
                tmux new-window -n $window_name -c $worktree_path
            end
        end

        set -a created_windows $window_name
    end

    echo ""
    echo "Created "(count $created_windows)" window(s)"

    if test (count $failed_branches) -gt 0
        echo "Failed: "(string join ", " $failed_branches)
    end

    echo ""
    echo "Navigation:"
    echo "  prefix + n/p       Next/previous window"
    echo "  prefix + <number>  Jump to window by number"
    echo "  prefix + w         Window list"

    # Return to first created window
    if test (count $created_windows) -gt 0
        tmux select-window -t $created_windows[1]
    end
end
