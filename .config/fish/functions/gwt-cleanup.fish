function gwt-cleanup --description "Clean up stale worktree devcontainer instances"
    # Usage: gwt-cleanup [--prune] [--dry-run] [--force]
    #
    # Identifies and removes devcontainer instances for worktrees that
    # no longer exist.
    #
    # Options:
    #   --prune, -p    Remove stale instances (default: just list)
    #   --dry-run, -n  Show what would be removed without doing it
    #   --force, -f    Skip confirmation prompts
    #   --all, -a      Check all instances, not just current repo's

    set -l do_prune false
    set -l do_dry_run false
    set -l do_force false
    set -l do_all false

    for arg in $argv
        switch $arg
            case --prune -p
                set do_prune true
            case --dry-run -n
                set do_dry_run true
            case --force -f
                set do_force true
            case --all -a
                set do_all true
            case --help -h
                echo "Usage: gwt-cleanup [--prune] [--dry-run] [--force] [--all]"
                echo ""
                echo "Clean up devcontainer instances for deleted worktrees."
                echo ""
                echo "Options:"
                echo "  --prune, -p    Remove stale instances"
                echo "  --dry-run, -n  Show what would be removed"
                echo "  --force, -f    Skip confirmation"
                echo "  --all, -a      Check all instances, not just current repo"
                return 0
        end
    end

    set -l instance_base "$HOME/.devcontainer/instances"
    set -l workspace_base "$HOME/.devcontainer/workspaces"

    if not test -d "$instance_base"
        echo "No devcontainer instances found at $instance_base"
        return 0
    end

    # Get current repo name if in a git repo
    set -l repo ""
    if git rev-parse --git-dir >/dev/null 2>&1
        set repo (basename (git rev-parse --show-toplevel))
    end

    # Get list of current worktrees
    set -l active_worktrees
    if test -n "$repo"; and not $do_all
        # Get worktrees for current repo
        for wt in (git worktree list --porcelain 2>/dev/null | grep "^worktree " | string replace "worktree " "")
            set -l wt_name (basename $wt)
            set -l instance_name (string replace -a "/" "-" $wt_name)
            set -a active_worktrees $instance_name
        end
    end

    # Find stale instances
    set -l stale_instances
    set -l stale_workspaces

    for instance_dir in $instance_base/*/
        set -l instance_name (basename $instance_dir)

        # Skip 'default' instance
        if test "$instance_name" = "default"
            continue
        end

        # If not --all, only check instances matching current repo
        if not $do_all; and test -n "$repo"
            if not string match -q "$repo-*" $instance_name
                continue
            end
        end

        # Check if this instance has an active worktree
        set -l is_active false
        for active in $active_worktrees
            if test "$active" = "$instance_name"
                set is_active true
                break
            end
        end

        if not $is_active
            # Verify worktree really doesn't exist by checking the path
            # Instance name format: repo-branch
            set -l potential_paths
            set -a potential_paths "../$instance_name"

            set -l worktree_exists false
            for path in $potential_paths
                if test -d "$path"
                    set worktree_exists true
                    break
                end
            end

            if not $worktree_exists
                set -a stale_instances $instance_name
                if test -d "$workspace_base/$instance_name"
                    set -a stale_workspaces $instance_name
                end
            end
        end
    end

    # Report findings
    if test (count $stale_instances) -eq 0
        echo "✅ No stale devcontainer instances found"
        return 0
    end

    echo "Found "(count $stale_instances)" stale instance(s):"
    echo ""

    for instance in $stale_instances
        set -l instance_size ""
        if command -q du
            set instance_size (du -sh "$instance_base/$instance" 2>/dev/null | cut -f1)
        end
        echo "  📦 $instance ($instance_size)"
        echo "     Instance: $instance_base/$instance"
        if contains $instance $stale_workspaces
            echo "     Workspace: $workspace_base/$instance"
        end
    end

    echo ""

    # Dry run - just show what would be done
    if $do_dry_run
        echo "Dry run - would remove:"
        for instance in $stale_instances
            echo "  rm -rf $instance_base/$instance"
            if contains $instance $stale_workspaces
                echo "  rm -rf $workspace_base/$instance"
            end
        end
        return 0
    end

    # Prune if requested
    if $do_prune
        # Confirm unless --force
        if not $do_force
            read -P "Remove these "(count $stale_instances)" instance(s)? [y/N] " response
            if test "$response" != "y"; and test "$response" != "Y"
                echo "Cancelled"
                return 0
            end
        end

        # Stop any running containers first
        if command -q docker
            for instance in $stale_instances
                set -l container_name "devcontainer-$instance"
                if docker ps -q --filter "name=$container_name" 2>/dev/null | grep -q .
                    echo "Stopping container: $container_name"
                    docker stop $container_name 2>/dev/null
                end
            end
        end

        # Remove instances and workspaces
        for instance in $stale_instances
            echo "Removing: $instance"
            rm -rf "$instance_base/$instance"
            if contains $instance $stale_workspaces
                rm -rf "$workspace_base/$instance"
            end
        end

        echo ""
        echo "✅ Removed "(count $stale_instances)" stale instance(s)"
    else
        echo "Run with --prune to remove these instances"
    end
end
