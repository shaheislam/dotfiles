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

    # Resolve to main repo name (not worktree name)
    set -l repo (basename (realpath (git rev-parse --git-common-dir)"/.."))

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

    # Find agent-state.sh script
    set -l agent_state_script ""
    for p in ~/dotfiles/scripts/agent-state.sh ~/dotfiles-gastownbeads/scripts/agent-state.sh
        if test -x "$p"
            set agent_state_script $p
            break
        end
    end

    # Print header
    echo ""
    if test -n "$agent_state_script"
        printf "%-40s %-20s %-15s %-18s %-10s\n" "WORKTREE" "BRANCH" "CONTAINER" "AGENT" "STATUS"
        printf "%-40s %-20s %-15s %-18s %-10s\n" (string repeat -n 40 "-") (string repeat -n 20 "-") (string repeat -n 15 "-") (string repeat -n 18 "-") (string repeat -n 10 "-")
    else
        printf "%-40s %-20s %-15s %-10s\n" "WORKTREE" "BRANCH" "CONTAINER" "STATUS"
        printf "%-40s %-20s %-15s %-10s\n" (string repeat -n 40 "-") (string repeat -n 20 "-") (string repeat -n 15 "-") (string repeat -n 10 "-")
    end

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

        # Derive agent state
        set -l agent_display "-"
        set -l agent_color normal
        if test -n "$agent_state_script"
            set -l agent_json ($agent_state_script $wt_path --json 2>/dev/null)
            if test -n "$agent_json"
                set -l astate (echo $agent_json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('state','none'))" 2>/dev/null; or echo "none")
                set -l aiter (echo $agent_json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('iteration',''))" 2>/dev/null; or echo "")
                set -l amax (echo $agent_json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('max_iterations',''))" 2>/dev/null; or echo "")

                switch $astate
                    case running
                        set agent_color green
                        if test -n "$aiter" -a "$aiter" != "0" -a -n "$amax"
                            set agent_display "▶ running [$aiter/$amax]"
                        else
                            set agent_display "▶ running"
                        end
                    case idle
                        set agent_color yellow
                        set agent_display "⏸ idle"
                    case stuck
                        set agent_color red
                        if test -n "$aiter" -a "$aiter" != "0" -a -n "$amax"
                            set agent_display "⚠ stuck [$aiter/$amax]"
                        else
                            set agent_display "⚠ stuck"
                        end
                    case completed
                        set agent_color cyan
                        set agent_display "✓ done"
                    case dead
                        set agent_color red
                        set agent_display "✗ dead"
                    case none '*'
                        set agent_display "-"
                        set agent_color normal
                end
            end
        end

        # Truncate path for display
        set -l display_path $wt_path
        if test (string length $wt_path) -gt 38
            set display_path "..."(string sub -s -35 $wt_path)
        end

        if test -n "$agent_state_script"
            printf "%s%-38s %-20s %-15s %s%-18s%s %s\n" $marker $display_path $wt_branch $instance_name (set_color $agent_color) $agent_display (set_color normal) $container_status
        else
            printf "%s%-38s %-20s %-15s %s\n" $marker $display_path $wt_branch $instance_name $container_status
        end
    end

    echo ""

    # Summary
    echo "Container: running | stopped | ready"
    if test -n "$agent_state_script"
        printf "Agent:     %s▶ running%s | %s⏸ idle%s | %s⚠ stuck%s | %s✓ done%s | %s✗ dead%s\n" \
            (set_color green) (set_color normal) \
            (set_color yellow) (set_color normal) \
            (set_color red) (set_color normal) \
            (set_color cyan) (set_color normal) \
            (set_color red) (set_color normal)
    end
    echo ""
    echo "Commands:"
    echo "  gwt-dev <branch> -e     Create worktree + start devcontainer"
    echo "  gwt-claude <branch>     Launch Claude in worktree's devcontainer"
    echo "  gwt-cleanup             Remove stale devcontainer instances"
end
