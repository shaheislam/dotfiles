function gwt-status --description "Show worktree + devcontainer status"
    # Usage: gwt-status [--all]
    #
    # Display a table showing git worktrees and their associated
    # devcontainer instances with status information.
    #
    # Options:
    #   --all, -a    Show all instances, not just current repo's worktrees

    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    set -l show_all false
    if test "$argv[1]" = "--all"; or test "$argv[1]" = "-a"
        set show_all true
    end

    set -l repo (basename (git rev-parse --show-toplevel))

    # Get worktrees
    set -l worktrees (git worktree list --porcelain 2>/dev/null)

    if test -z "$worktrees"
        echo "No worktrees found"
        return 0
    end

    # Parse worktrees into arrays
    set -l wt_paths
    set -l wt_branches
    set -l current_wt ""

    set -l current_path ""
    set -l current_branch ""

    for line in $worktrees
        if string match -q "worktree *" $line
            set current_path (string replace "worktree " "" $line)
        else if string match -q "branch *" $line
            set current_branch (string replace "branch refs/heads/" "" $line)
        else if string match -q "HEAD *" $line
            # Detached HEAD - use commit short hash
            set current_branch "(detached)"
        else if test -z "$line"
            # Empty line = end of entry
            if test -n "$current_path"
                set -a wt_paths $current_path
                if test -z "$current_branch"
                    set current_branch "(bare)"
                end
                set -a wt_branches $current_branch
            end
            set current_path ""
            set current_branch ""
        end
    end

    # Handle last entry (no trailing empty line)
    if test -n "$current_path"
        set -a wt_paths $current_path
        if test -z "$current_branch"
            set current_branch "(bare)"
        end
        set -a wt_branches $current_branch
    end

    # Get current worktree
    set current_wt (git rev-parse --show-toplevel 2>/dev/null)

    # Print header
    echo ""
    printf "%-40s %-20s %-15s %-10s\n" "WORKTREE" "BRANCH" "CONTAINER" "STATUS"
    printf "%-40s %-20s %-15s %-10s\n" (string repeat -n 40 "-") (string repeat -n 20 "-") (string repeat -n 15 "-") (string repeat -n 10 "-")

    # Get running devcontainers
    set -l running_containers
    if command -q docker
        set running_containers (docker ps --format '{{.Names}}' 2>/dev/null)
    end

    # Check devcontainer instances
    set -l instance_base "$HOME/.devcontainer/instances"

    for i in (seq (count $wt_paths))
        set -l wt_path $wt_paths[$i]
        set -l wt_branch $wt_branches[$i]
        set -l wt_name (basename $wt_path)

        # Clean instance name (replace / with -)
        set -l instance_name (string replace -a "/" "-" $wt_name)

        # Determine container status
        set -l container_status "-"

        # Check instance storage exists
        set -l has_instance false
        if test -d "$instance_base/$instance_name"
            set has_instance true
        end

        # Check if container is running
        set -l is_running false
        for container in $running_containers
            if string match -q "*$instance_name*" $container
                set is_running true
                break
            end
        end

        # Determine status display
        # All worktrees can launch devcontainers via the built-in devcon claude sandbox
        if $is_running
            set container_status "running"
        else if $has_instance
            set container_status "stopped"
        else
            set container_status "ready"
        end

        # Mark current worktree
        set -l marker ""
        if test "$wt_path" = "$current_wt"
            set marker "→ "
        else
            set marker "  "
        end

        # Truncate path for display
        set -l display_path $wt_path
        if test (string length $wt_path) -gt 38
            set display_path "..."(string sub -s -35 $wt_path)
        end

        printf "%s%-38s %-20s %-15s %s\n" $marker $display_path $wt_branch $instance_name $container_status
    end

    echo ""

    # Summary
    echo "Legend: running | stopped | devcontainer ready | no devcontainer"
    echo ""
    echo "Commands:"
    echo "  gwt-dev <branch> -e     Create worktree + start devcontainer"
    echo "  gwt-claude <branch>     Launch Claude in worktree's devcontainer"
    echo "  gwt-cleanup             Remove stale devcontainer instances"
end
