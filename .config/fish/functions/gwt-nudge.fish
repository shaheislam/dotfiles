function gwt-nudge --description "Nudge an idle or stuck agent (Gastown gt nudge equivalent)"
    # Usage: gwt-nudge [worktree-name|path] [--message MSG] [--sling] [--help]
    #
    # Sends a WAKE nudge to an idle Claude agent in a worktree.
    # Equivalent to Gastown's 'gt nudge' command.
    #
    # GUPP principle: "If there is work on your hook, YOU MUST RUN IT."
    # Nudging sends a tmux keystroke to wake the agent, and optionally
    # slings a message to its hook bead (if Beads is initialized).
    #
    # Options:
    #   --message MSG   Custom nudge message (default: "Please continue working on the task")
    #   --sling         Also create an ephemeral hook bead nudge event
    #   --force         Nudge even if agent appears running (not just idle/stuck)
    #   --help, -h      Show usage

    set -l target ""
    set -l nudge_msg "Please continue working on the task. Check for any pending actions."
    set -l do_sling false
    set -l force false

    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case --help -h
                echo "Usage: gwt-nudge [worktree-name|path] [options]"
                echo ""
                echo "Nudge an idle or stuck agent (Gastown gt nudge equivalent)."
                echo ""
                echo "Options:"
                echo "  --message MSG   Custom nudge message"
                echo "  --sling         Also sling an ephemeral hook event bead"
                echo "  --force         Nudge even if agent appears running"
                echo "  --help, -h      Show this help"
                echo ""
                echo "Examples:"
                echo "  gwt-nudge                           # Nudge agent in current worktree"
                echo "  gwt-nudge my-feature                # Nudge agent in named worktree"
                echo "  gwt-nudge --message 'Check CI'      # Nudge with custom message"
                echo "  gwt-nudge --sling                   # Nudge + sling hook bead event"
                return 0
            case --message
                set i (math $i + 1)
                if test $i -le (count $argv)
                    set nudge_msg $argv[$i]
                end
            case --sling
                set do_sling true
            case --force
                set force true
            case --
                # End of options
            case '*'
                if test -z "$target"
                    set target $argv[$i]
                end
        end
        set i (math $i + 1)
    end

    # Resolve worktree path
    set -l worktree_path ""
    if test -z "$target"
        # Use current directory
        set worktree_path (pwd)
    else if test -d "$target"
        set worktree_path $target
    else
        # Search for worktree by name
        set -l candidates (git worktree list --porcelain 2>/dev/null | grep "^worktree " | awk '{print $2}' | grep -i "$target" 2>/dev/null)
        if test (count $candidates) -eq 1
            set worktree_path $candidates[1]
        else if test (count $candidates) -gt 1
            echo "Multiple worktrees match '$target':" >&2
            for c in $candidates
                echo "  $c" >&2
            end
            return 1
        else
            echo "No worktree found matching '$target'" >&2
            return 1
        end
    end

    if not test -d "$worktree_path"
        echo "Error: Not a directory: $worktree_path" >&2
        return 1
    end

    # Check ticket state
    set -l ticket_state "$worktree_path/.claude/ticket-execute.local.md"
    if not test -f "$ticket_state"
        echo "No active ticket in $worktree_path" >&2
        return 1
    end

    # Get tmux session/window from ticket state
    set -l tmux_session (grep "^tmux_session:" "$ticket_state" 2>/dev/null | awk '{print $2}' | tr -d '"')
    set -l tmux_window (grep "^tmux_window:" "$ticket_state" 2>/dev/null | awk '{print $2}' | tr -d '"')
    set -l issue_key (grep "^issue_key:" "$ticket_state" 2>/dev/null | awk '{print $2}' | tr -d '"')

    # Check agent state unless --force
    if not $force
        set -l agent_state_script "$HOME/dotfiles-gastown/scripts/agent-state.sh"
        if test -x "$agent_state_script"
            set -l state_json ("$agent_state_script" "$worktree_path" --json 2>/dev/null)
            set -l current_state (echo "$state_json" | jq -r '.state // "unknown"' 2>/dev/null)
            if test "$current_state" = running
                echo "Agent is running (use --force to nudge anyway): $worktree_path"
                return 0
            end
        end
    end

    echo "Nudging agent in $worktree_path..."
    if test -n "$issue_key"
        echo "  Issue: $issue_key"
    end

    set -l nudged false

    # Tier 0: tmux keystroke nudge (agent-triage WAKE action)
    set -l triage_script "$HOME/dotfiles-gastown/scripts/agent-triage.sh"
    if test -x "$triage_script"
        if "$triage_script" "$worktree_path" --action WAKE 2>/dev/null
            set nudged true
            echo "  Sent tmux WAKE keystroke"
        end
    else if test -n "$tmux_session"
        # Direct tmux send-keys fallback
        set -l target_pane ""
        if test -n "$tmux_window"
            set target_pane "$tmux_session:$tmux_window"
        else
            set target_pane "$tmux_session"
        end
        if tmux send-keys -t "$target_pane" "" Enter 2>/dev/null
            set nudged true
            echo "  Sent tmux keystroke to $target_pane"
        end
    end

    # Tier 2: sling ephemeral hook event bead (Gastown wisp pattern)
    if $do_sling
        if command -q bd; and test -d "$worktree_path/.beads"
            # Create an ephemeral bead event (wisp) for the nudge
            set -l event_title "nudge: $nudge_msg"
            set -l wisp_id (cd "$worktree_path" && bd create "$event_title" \
                --ephemeral \
                --type event \
                --event-category "agent.nudged" \
                --event-target "$issue_key" \
                --silent 2>/dev/null)
            if test -n "$wisp_id"
                echo "  Slung hook event wisp: $wisp_id (ephemeral)"
            end
        else
            echo "  Beads not available for sling (skipping)"
        end
    end

    if $nudged
        echo "  Done. Agent nudged."
    else
        echo "  Warning: Could not find tmux session to nudge. Is the agent still running?" >&2
        echo "  Try: gwt-status to check worktree state" >&2
        return 1
    end
end
