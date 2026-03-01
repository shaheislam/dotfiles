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
        # Resolve to main repo name (not worktree name)
        set repo (basename (realpath (git rev-parse --git-common-dir)"/.."))
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
        if test "$instance_name" = default
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
        echo "No stale devcontainer instances found"
        return 0
    end

    echo "Found "(count $stale_instances)" stale instance(s):"
    echo ""

    for instance in $stale_instances
        set -l instance_size ""
        if command -q du
            set instance_size (du -sh "$instance_base/$instance" 2>/dev/null | cut -f1)
        end
        echo "  $instance ($instance_size)"
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
        set -l to_remove

        if $do_force
            # --force: remove all without picker
            set to_remove $stale_instances
        else
            # FZF multiselect: build entries with size and workspace info
            set -l fzf_entries
            for instance in $stale_instances
                set -l size ""
                if command -q du
                    set size (du -sh "$instance_base/$instance" 2>/dev/null | cut -f1)
                end
                set -l has_ws no
                if contains $instance $stale_workspaces
                    set has_ws yes
                end
                set -a fzf_entries (printf '%-40s  %-6s  %-14s\t%s' "$instance" "$size" "workspace:$has_ws" "$instance_base/$instance")
            end

            set -l selected (printf '%s\n' $fzf_entries \
                | fzf \
                    --multi \
                    --exit-0 \
                    --tabstop=1 \
                    -d '\t' \
                    --with-nth=1 \
                    --prompt='prune instances ❯ ' \
                    --header='name                                      size    workspace' \
                    --preview='ls -la {2}' \
                    --preview-window=bottom:30%:wrap \
                    --bind='ctrl-/:toggle-preview' \
                | cut -f1 | string trim)
            # Extract instance name (first word) from padded selection
            set selected (for line in $selected; string match -r '^\S+' -- "$line"; end)

            if test -z "$selected"
                echo "No instances selected"
                return 0
            end
            set to_remove $selected
        end

        # Stop any running containers first
        if command -q docker
            for instance in $to_remove
                set -l container_name "devcontainer-$instance"
                if docker ps -q --filter "name=$container_name" 2>/dev/null | grep -q .
                    echo "Stopping container: $container_name"
                    docker stop $container_name 2>/dev/null
                end
            end
        end

        # Remove selected instances and workspaces
        for instance in $to_remove
            echo "Removing: $instance"
            rm -rf "$instance_base/$instance"
            if contains $instance $stale_workspaces
                rm -rf "$workspace_base/$instance"
            end
        end

        echo ""
        echo "Removed "(count $to_remove)" stale instance(s)"
    else
        echo "Run with --prune to remove these instances"
    end

    # Clean up orphaned claude-code-config-* Docker volumes from old per-container approach
    if command -q docker
        set -l orphaned_vols (docker volume ls -q --filter "name=claude-code-config-" 2>/dev/null)
        if test (count $orphaned_vols) -gt 0
            echo ""
            echo "Found "(count $orphaned_vols)" orphaned claude-code-config volume(s):"
            for vol in $orphaned_vols
                echo "  $vol"
            end
            if $do_prune
                for vol in $orphaned_vols
                    echo "Removing orphaned volume: $vol"
                    docker volume rm $vol 2>/dev/null
                end
                echo "Removed "(count $orphaned_vols)" orphaned volume(s)"
            else
                echo "Run with --prune to remove these volumes"
            end
        end
    end
end
