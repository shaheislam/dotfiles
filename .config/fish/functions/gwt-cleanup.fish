function gwt-cleanup --description "Clean up stale worktree devcontainer instances (archive-by-default)"
    # Usage: gwt-cleanup [--prune | --purge-now | --restore NAME | --purge-trash]
    #
    # Identifies and archives devcontainer instances for worktrees that
    # no longer exist. Archive lives at ~/.devcontainer/.trash/<ts>-<name>/.
    #
    # Default safety posture: --prune archives (matches tmux-session-trash
    # and `entire` checkpoints). --purge-now is the explicit destructive flag.

    set -l do_prune false
    set -l do_purge_now false
    set -l do_dry_run false
    set -l do_force false
    set -l do_all false
    set -l do_reconcile false
    set -l do_restore false
    set -l restore_name ""
    set -l do_purge_trash false
    set -l ttl_days 30

    set -l trash_base "$HOME/.devcontainer/.trash"

    set -l skip_next false
    set -l argc (count $argv)
    set -l indices
    if test $argc -gt 0
        set indices (seq 1 $argc)
    end
    for i in $indices
        if $skip_next
            set skip_next false
            continue
        end
        set -l arg $argv[$i]
        switch $arg
            case --prune -p --archive
                set do_prune true
            case --purge-now
                set do_prune true
                set do_purge_now true
            case --dry-run -n
                set do_dry_run true
            case --force -f
                set do_force true
            case --all -a
                set do_all true
            case --reconcile -r
                set do_reconcile true
            case --restore
                set do_restore true
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set restore_name $argv[$next_i]
                    set skip_next true
                end
            case --purge-trash
                set do_purge_trash true
            case --ttl-days
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set ttl_days $argv[$next_i]
                    set skip_next true
                end
            case --help -h
                echo "Usage: gwt-cleanup [OPTIONS]"
                echo ""
                echo "Clean up devcontainer instances for deleted worktrees."
                echo "Archive-by-default: --prune moves to ~/.devcontainer/.trash/, not rm -rf."
                echo ""
                echo "Operations:"
                echo "  --prune, -p          Archive stale instances to .trash/ (safe default)"
                echo "  --purge-now          rm -rf stale instances immediately (old --prune)"
                echo "  --restore NAME       Restore archived instance from .trash/"
                echo "  --purge-trash        Permanently delete .trash/ contents"
                echo "  --reconcile, -r      Find and synthesize missed Obsidian session notes"
                echo ""
                echo "Modifiers:"
                echo "  --dry-run, -n        Show what would happen without doing it"
                echo "  --force, -f          Skip fzf picker / confirmation prompts"
                echo "  --all, -a            Check all instances, not just current repo"
                echo "  --ttl-days N         Age filter for --purge-trash (default: 30)"
                echo "  --archive            Alias for --prune (explicit)"
                echo ""
                echo "Examples:"
                echo "  gwt-cleanup                              # list stale instances"
                echo "  gwt-cleanup --prune                      # archive (recoverable)"
                echo "  gwt-cleanup --purge-now --force          # immediate hard delete"
                echo "  gwt-cleanup --restore feature-x          # bring it back"
                echo "  gwt-cleanup --purge-trash --ttl-days 30  # purge archives older than 30d"
                return 0
        end
    end

    # Standalone reconcile: run session reconciliation and return
    if $do_reconcile; and not $do_prune
        set -l synth_script "$HOME/dotfiles/scripts/obsidian/session-synthesize.sh"
        if test -x "$synth_script"
            bash "$synth_script" --reconcile
        else
            echo "Error: session-synthesize.sh not found" >&2
            return 1
        end
        return 0
    end

    set -l instance_base "$HOME/.devcontainer/instances"
    set -l workspace_base "$HOME/.devcontainer/workspaces"

    # Standalone restore: bring an archived instance back from .trash/
    if $do_restore
        if test -z "$restore_name"
            echo "Error: --restore requires a name" >&2
            echo "  gwt-cleanup --restore <instance-name>" >&2
            return 1
        end
        if not test -d "$trash_base"
            echo "No archives found at $trash_base" >&2
            return 1
        end
        # Find most recent archive matching *-<restore_name>
        set -l matches
        for entry in $trash_base/*-$restore_name
            if test -d "$entry"
                set -a matches $entry
            end
        end
        if test (count $matches) -eq 0
            echo "Error: no archive matches '$restore_name' in $trash_base" >&2
            return 1
        end
        # Sort and take most recent (timestamp prefix means lexical = chronological)
        set -l archive_dir (printf '%s\n' $matches | sort | tail -1)
        set -l archive_name (basename -- $archive_dir)
        echo "Restoring from: $archive_dir"
        if test -d "$archive_dir/instance"
            if test -d "$instance_base/$restore_name"
                echo "Error: $instance_base/$restore_name already exists; remove it first" >&2
                return 1
            end
            mkdir -p "$instance_base"
            mv "$archive_dir/instance" "$instance_base/$restore_name"
            echo "  → $instance_base/$restore_name"
        end
        if test -d "$archive_dir/workspace"
            if test -d "$workspace_base/$restore_name"
                echo "Error: $workspace_base/$restore_name already exists; remove it first" >&2
                return 1
            end
            mkdir -p "$workspace_base"
            mv "$archive_dir/workspace" "$workspace_base/$restore_name"
            echo "  → $workspace_base/$restore_name"
        end
        rmdir "$archive_dir" 2>/dev/null
        echo "Restored: $restore_name (from $archive_name)"
        return 0
    end

    # Standalone purge-trash: hard-delete .trash/ contents (subject to --ttl-days)
    if $do_purge_trash
        if not test -d "$trash_base"
            echo "No archives at $trash_base"
            return 0
        end
        set -l candidates
        if test "$ttl_days" -gt 0 2>/dev/null
            for entry in (find "$trash_base" -mindepth 1 -maxdepth 1 -type d -mtime +$ttl_days 2>/dev/null)
                set -a candidates $entry
            end
        else
            for entry in $trash_base/*/
                set -a candidates (string trim -r -c / -- $entry)
            end
        end
        if test (count $candidates) -eq 0
            echo "No archives older than $ttl_days days in $trash_base"
            return 0
        end
        echo "Found "(count $candidates)" archive(s) eligible for purge:"
        for c in $candidates
            set -l size ""
            if command -q du
                set size (du -sh "$c" 2>/dev/null | cut -f1)
            end
            echo "  "(basename -- $c)" ($size)"
        end
        if $do_dry_run
            echo ""
            echo "Dry run - would rm -rf the above"
            return 0
        end
        if not $do_force
            read -P "Permanently delete "(count $candidates)" archive(s)? [y/N] " confirm
            if not string match -qi y -- $confirm
                echo Aborted
                return 0
            end
        end
        for c in $candidates
            rm -rf "$c"
        end
        echo "Purged "(count $candidates)" archive(s)"
        return 0
    end

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
        if $do_purge_now
            echo "Dry run - would PURGE (rm -rf):"
            for instance in $stale_instances
                echo "  rm -rf $instance_base/$instance"
                if contains $instance $stale_workspaces
                    echo "  rm -rf $workspace_base/$instance"
                end
            end
        else
            echo "Dry run - would archive to $trash_base/<ts>-<name>/:"
            for instance in $stale_instances
                echo "  $instance_base/$instance → $trash_base/<ts>-$instance/instance"
                if contains $instance $stale_workspaces
                    echo "  $workspace_base/$instance → $trash_base/<ts>-$instance/workspace"
                end
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

        if $do_purge_now
            # Hard delete (old --prune behaviour)
            for instance in $to_remove
                echo "Purging: $instance"
                rm -rf "$instance_base/$instance"
                if contains $instance $stale_workspaces
                    rm -rf "$workspace_base/$instance"
                end
            end
            echo ""
            echo "Purged "(count $to_remove)" stale instance(s)"
        else
            # Archive to .trash/ (default --prune behaviour)
            mkdir -p "$trash_base"
            set -l ts (date +%Y%m%d_%H%M%S)
            for instance in $to_remove
                set -l archive_dir "$trash_base/$ts-$instance"
                echo "Archiving: $instance → $archive_dir"
                mkdir -p "$archive_dir"
                if test -d "$instance_base/$instance"
                    mv "$instance_base/$instance" "$archive_dir/instance"
                end
                if contains $instance $stale_workspaces
                    if test -d "$workspace_base/$instance"
                        mv "$workspace_base/$instance" "$archive_dir/workspace"
                    end
                end
            end
            echo ""
            echo "Archived "(count $to_remove)" stale instance(s) to $trash_base/"
            echo "Restore:  gwt-cleanup --restore <name>"
            echo "Purge:    gwt-cleanup --purge-trash --ttl-days $ttl_days"
        end
    else
        echo "Run with --prune to archive these (or --purge-now to delete immediately)"
    end

    # Reconcile missed Obsidian session syntheses (explicit flag only)
    if $do_reconcile
        set -l synth_script "$HOME/dotfiles/scripts/obsidian/session-synthesize.sh"
        if test -x "$synth_script"
            echo ""
            echo "Reconciling missed Obsidian session syntheses..."
            bash "$synth_script" --reconcile; or true
        end
    end

    # Clean up orphaned claude-code-config-* Docker volumes from old per-container approach
    # Note: Docker volumes can't be cheaply archived, so removal requires --purge-now.
    if command -q docker
        set -l orphaned_vols (docker volume ls -q --filter "name=claude-code-config-" 2>/dev/null)
        if test (count $orphaned_vols) -gt 0
            echo ""
            echo "Found "(count $orphaned_vols)" orphaned claude-code-config volume(s):"
            for vol in $orphaned_vols
                echo "  $vol"
            end
            if $do_purge_now
                for vol in $orphaned_vols
                    echo "Removing orphaned volume: $vol"
                    docker volume rm $vol 2>/dev/null
                end
                echo "Removed "(count $orphaned_vols)" orphaned volume(s)"
            else
                echo "Run with --purge-now to remove these volumes (volumes are not archivable)"
            end
        end
    end
end
