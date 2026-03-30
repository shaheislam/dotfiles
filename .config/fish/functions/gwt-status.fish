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
    set -l show_convoy false
    for arg in $argv
        switch $arg
            case --all -a
                set show_all true
            case --convoy -c
                set show_convoy true
        end
    end

    # Convoy view: group agents by convoy
    if $show_convoy
        _gwt_status_convoy
        return $status
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

    # Detect codex companion for job status
    set -l codex_companion "$HOME/.claude/plugins/marketplaces/openai-codex/plugins/codex/scripts/codex-companion.mjs"
    set -l has_codex false
    if command -q node; and test -f "$codex_companion"
        set has_codex true
    end

    # Print header
    echo ""
    if test -n "$agent_state_script"; and $has_codex
        printf "%-40s %-20s %-15s %-18s %-15s %-10s\n" WORKTREE BRANCH CONTAINER AGENT CODEX STATUS
        printf "%-40s %-20s %-15s %-18s %-15s %-10s\n" (string repeat -n 40 "-") (string repeat -n 20 "-") (string repeat -n 15 "-") (string repeat -n 18 "-") (string repeat -n 15 "-") (string repeat -n 10 "-")
    else if test -n "$agent_state_script"
        printf "%-40s %-20s %-15s %-18s %-10s\n" WORKTREE BRANCH CONTAINER AGENT STATUS
        printf "%-40s %-20s %-15s %-18s %-10s\n" (string repeat -n 40 "-") (string repeat -n 20 "-") (string repeat -n 15 "-") (string repeat -n 18 "-") (string repeat -n 10 "-")
    else if $has_codex
        printf "%-40s %-20s %-15s %-15s %-10s\n" WORKTREE BRANCH CONTAINER CODEX STATUS
        printf "%-40s %-20s %-15s %-15s %-10s\n" (string repeat -n 40 "-") (string repeat -n 20 "-") (string repeat -n 15 "-") (string repeat -n 15 "-") (string repeat -n 10 "-")
    else
        printf "%-40s %-20s %-15s %-10s\n" WORKTREE BRANCH CONTAINER STATUS
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
        set -l container_status -

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
            set container_status running
        else if $has_instance
            set container_status stopped
        else
            set container_status ready
        end

        # Mark current worktree
        set -l marker ""
        if test "$wt_path" = "$current_wt"
            set marker "→ "
        else
            set marker "  "
        end

        # Derive agent state
        set -l agent_display -
        set -l agent_color normal
        if test -n "$agent_state_script"
            set -l agent_json ($agent_state_script $wt_path --json 2>/dev/null)
            if test -n "$agent_json"
                set -l astate (echo $agent_json | jq -r '.state // "none"' 2>/dev/null; or echo "none")
                set -l aiter (echo $agent_json | jq -r '.iteration // ""' 2>/dev/null; or echo "")
                set -l amax (echo $agent_json | jq -r '.max_iterations // ""' 2>/dev/null; or echo "")

                switch $astate
                    case running
                        set agent_color green
                        if test -n "$aiter" -a "$aiter" != 0 -a -n "$amax"
                            set agent_display "▶ running [$aiter/$amax]"
                        else
                            set agent_display "▶ running"
                        end
                    case idle
                        set agent_color yellow
                        set agent_display "⏸ idle"
                    case stuck
                        set agent_color red
                        if test -n "$aiter" -a "$aiter" != 0 -a -n "$amax"
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
                        set agent_display -
                        set agent_color normal
                end
            end
        end

        # Truncate path for display
        set -l display_path $wt_path
        if test (string length $wt_path) -gt 38
            set display_path "..."(string sub -s -35 $wt_path)
        end

        # Codex job status
        set -l codex_display -
        if $has_codex
            set -l codex_json (cd "$wt_path" 2>/dev/null; and node "$codex_companion" status --json 2>/dev/null | string collect)
            if test -n "$codex_json"
                set -l active_count (echo "$codex_json" | jq -r '.active // 0' 2>/dev/null)
                set -l last_status (echo "$codex_json" | jq -r '.lastStatus // "none"' 2>/dev/null)
                if test "$active_count" -gt 0 2>/dev/null
                    set codex_display "[$active_count active]"
                else if test "$last_status" != none -a "$last_status" != null
                    set codex_display "$last_status"
                end
            end
        end

        if test -n "$agent_state_script"; and $has_codex
            printf "%s%-38s %-20s %-15s %s%-18s%s %-15s %s\n" $marker $display_path $wt_branch $instance_name (set_color $agent_color) $agent_display (set_color normal) $codex_display $container_status
        else if test -n "$agent_state_script"
            printf "%s%-38s %-20s %-15s %s%-18s%s %s\n" $marker $display_path $wt_branch $instance_name (set_color $agent_color) $agent_display (set_color normal) $container_status
        else if $has_codex
            printf "%s%-38s %-20s %-15s %-15s %s\n" $marker $display_path $wt_branch $instance_name $codex_display $container_status
        else
            printf "%s%-38s %-20s %-15s %s\n" $marker $display_path $wt_branch $instance_name $container_status
        end
    end

    echo ""

    # Beads summary (if available)
    if command -q bd; and test -d ".beads"
        set -l open_count (bd count --status=open 2>/dev/null | string trim)
        set -l in_prog_count (bd count --status=in_progress 2>/dev/null | string trim)
        set -l blocked_count (bd blocked 2>/dev/null | grep -c "^\(○\|◐\)" 2>/dev/null; or echo 0)
        if test -n "$open_count" -o -n "$in_prog_count"
            printf "Beads:     %s open, %s in-progress, %s blocked\n" \
                (test -n "$open_count"; and echo $open_count; or echo 0) \
                (test -n "$in_prog_count"; and echo $in_prog_count; or echo 0) \
                $blocked_count
        end
    end

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
    echo "  gwt-status --convoy     Group by convoy with progress"
end

function _gwt_status_convoy --description "Show agents grouped by convoy"
    set -l convoy_script "$HOME/dotfiles/scripts/convoy.sh"
    if not test -x "$convoy_script"
        set convoy_script "$HOME/dotfiles-gastown/scripts/convoy.sh"
    end
    if not test -x "$convoy_script"
        echo "Error: convoy.sh not found"
        return 1
    end

    # Get all active convoys as JSON
    set -l convoys_json (bash "$convoy_script" list --active --json 2>/dev/null)
    if test -z "$convoys_json" -o "$convoys_json" = "[]"
        echo ""
        echo "No active convoys."
        echo ""
        echo "Start a plan: gwtt --plan <name> ..."
        return 0
    end

    # Find agent-state.sh
    set -l agent_state_script ""
    for p in ~/dotfiles/scripts/agent-state.sh ~/dotfiles-gastown/scripts/agent-state.sh
        if test -x "$p"
            set agent_state_script $p
            break
        end
    end

    # Get all worktrees for cross-referencing
    set -l all_worktrees (git worktree list --porcelain 2>/dev/null)

    echo ""

    # Parse and display each convoy using jq + Fish formatting
    set -l convoy_count (printf '%s' "$convoys_json" | jq 'length' 2>/dev/null; or echo 0)
    for ci in (seq 0 (math "$convoy_count - 1"))
        set -l cname (printf '%s' "$convoys_json" | jq -r ".[$ci].name" 2>/dev/null)
        set -l cid (printf '%s' "$convoys_json" | jq -r ".[$ci].id" 2>/dev/null)
        set -l total (printf '%s' "$convoys_json" | jq -r ".[$ci].status | length" 2>/dev/null)
        set -l completed (printf '%s' "$convoys_json" | jq -r "[.[$ci].status[] | select(. == \"completed\")] | length" 2>/dev/null)
        set -l failed (printf '%s' "$convoys_json" | jq -r "[.[$ci].status[] | select(. == \"failed\")] | length" 2>/dev/null)
        set -l running (printf '%s' "$convoys_json" | jq -r "[.[$ci].status[] | select(. == \"running\")] | length" 2>/dev/null)
        set -l pending (printf '%s' "$convoys_json" | jq -r "[.[$ci].status[] | select(. == \"pending\")] | length" 2>/dev/null)

        # Progress bar
        set -l bar_len 25
        set -l filled 0
        if test "$total" -gt 0
            set filled (math "floor($completed / $total * $bar_len)")
        end
        set -l bar (string repeat -n $filled "█")(string repeat -n (math "$bar_len - $filled") "░")

        printf "\033[1m%s\033[0m (%s)\n" $cname $cid
        printf "  [%s] %s/%s complete" $bar $completed $total
        set -l parts
        test "$running" -gt 0; and set -a parts (printf "\033[0;32m%s running\033[0m" $running)
        test "$pending" -gt 0; and set -a parts (printf "\033[2m%s pending\033[0m" $pending)
        test "$failed" -gt 0; and set -a parts (printf "\033[0;31m%s failed\033[0m" $failed)
        if test (count $parts) -gt 0
            printf "  (%s)\n" (string join ", " $parts)
        else
            printf "\n"
        end

        # Show each ticket with agent state
        for ticket_line in (printf '%s' "$convoys_json" | jq -r ".[$ci].status | to_entries[] | \"\(.key)\t\(.value)\"" 2>/dev/null)
            set -l ticket (echo $ticket_line | cut -f1)
            set -l st (echo $ticket_line | cut -f2)
            set -l icon "?"
            switch $st
                case completed
                    set icon (printf "\033[0;32m✓\033[0m")
                case failed
                    set icon (printf "\033[0;31m✗\033[0m")
                case running
                    set icon (printf "\033[0;34m▶\033[0m")
                case pending
                    set icon (printf "\033[2m·\033[0m")
            end
            set -l agent_info ""
            if test -n "$agent_state_script" -a "$st" = running
                # Find worktree matching this ticket
                set -l ticket_lower (echo $ticket | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
                for state_file in ~/*/. claude/gwt-ticket.local.md
                    if test -f "$state_file"
                        if grep -qi "$ticket_lower\|$ticket" "$state_file" 2>/dev/null
                            set -l wt (dirname (dirname "$state_file"))
                            set -l aj (bash "$agent_state_script" "$wt" --json 2>/dev/null)
                            if test -n "$aj"
                                set -l ai (echo $aj | jq -r '.iteration // ""' 2>/dev/null)
                                set -l am (echo $aj | jq -r '.max_iterations // ""' 2>/dev/null)
                                if test -n "$ai" -a -n "$am"
                                    set agent_info " [$ai/$am]"
                                end
                            end
                            break
                        end
                    end
                end
            end
            printf "    %s %s: %s%s\n" $icon $ticket $st $agent_info
        end
        echo ""
    end

    echo "Commands:"
    echo "  gwt-convoy status <id>     Detailed convoy view"
    echo "  gwtt-plan resume <name>    Re-run failed tasks"
    echo "  gwt-status                 Full worktree table"
    echo ""
end
