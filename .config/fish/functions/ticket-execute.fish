function ticket-execute --description "Execute a ticket autonomously using devcontainer + ralph-loop"
    # Usage: ticket-execute [TICKET_KEY] [OPTIONS]
    #
    # Options:
    #   --max N        Max ralph-loop iterations (default: 20)
    #   --devcon       Use devcontainer for isolation
    #   --dry-run      Show what would be executed
    #   --status       Check execution status for a worktree
    #   --watch        Watch for completion and run post-completion hook
    #   --complete     Run post-completion hook manually
    #   --help         Show help
    #
    # If no ticket key provided, opens fzf picker

    # Parse special modes
    set -l mode "execute"
    set -l ticket_key ""
    set -l extra_args

    for arg in $argv
        switch $arg
            case --help -h
                echo "ticket-execute - Execute tickets autonomously"
                echo ""
                echo "Usage: ticket-execute [TICKET_KEY] [OPTIONS]"
                echo ""
                echo "Modes:"
                echo "  (default)      Execute a ticket"
                echo "  --status PATH  Check execution status"
                echo "  --watch PATH   Watch for completion"
                echo "  --complete PATH Run post-completion hook"
                echo ""
                echo "Options:"
                echo "  --max N        Max iterations (default: 20)"
                echo "  --sub NAME     Claude subscription profile (uses ~/.claude-NAME config dir)"
                echo "  --devcon       Use devcontainer for isolation"
                echo "  --dry-run      Show what would be executed"
                echo ""
                echo "Examples:"
                echo "  ticket-execute ENG-123         # Execute ticket"
                echo "  ticket-execute                 # fzf picker"
                echo "  ticket-execute --status .     # Check current dir"
                echo "  ticket-execute --watch ~/worktree"
                return 0
            case --status
                set mode "status"
            case --watch
                set mode "watch"
            case --complete
                set mode "complete"
            case '--*'
                set -a extra_args $arg
            case '*'
                if test -z "$ticket_key"
                    set ticket_key $arg
                else
                    set -a extra_args $arg
                end
        end
    end

    # Handle special modes
    switch $mode
        case "status"
            set -l path $ticket_key
            test -z "$path"; and set path "."
            ~/dotfiles/scripts/ticket-complete.sh --status $path
            return $status
        case "watch"
            set -l path $ticket_key
            test -z "$path"; and set path "."
            ~/dotfiles/scripts/ticket-complete.sh --watch $path
            return $status
        case "complete"
            set -l path $ticket_key
            test -z "$path"; and set path "."
            ~/dotfiles/scripts/ticket-complete.sh $path
            return $status
    end

    # Execute mode - need ticket details

    # Detect ticketing system
    set -l ticketing_system ""

    if test -f .claude/settings.local.json
        set ticketing_system (jq -r '.ticketing.system // empty' .claude/settings.local.json 2>/dev/null)
    end

    if test -z "$ticketing_system"
        if test -f .linear.toml
            set ticketing_system "linear"
        else
            set -l remote (git remote get-url origin 2>/dev/null)
            if string match -q "*petlab*" -- $remote; or string match -q "*dfe-digital*" -- $remote
                set ticketing_system "jira"
            else
                set ticketing_system "linear"
            end
        end
    end

    # If no ticket provided, use fzf to pick
    if test -z "$ticket_key"
        echo "No ticket specified, opening picker..."

        if test "$ticketing_system" = "linear"
            # Linear: list my issues
            if command -q linear
                set ticket_key (linear issue list --mine --state started,unstarted,backlog 2>/dev/null | \
                    fzf --header "Select Linear issue" --preview "linear issue view {1}" | \
                    awk '{print $1}')
            else
                echo "Error: linear CLI not installed"
                echo "Run: brew install schpet/tap/linear"
                return 1
            end
        else
            # Jira: list assigned issues
            if command -q acli
                set ticket_key (acli jira workitem search --jql "assignee = currentUser() AND status != Done" --output table 2>/dev/null | \
                    fzf --header "Select Jira issue" | \
                    awk '{print $1}')
            else
                echo "Error: acli not installed"
                return 1
            end
        end

        if test -z "$ticket_key"
            echo "No ticket selected"
            return 1
        end
    end

    # Fetch ticket details
    set -l title ""
    set -l description ""

    echo "Fetching ticket details for $ticket_key..."

    if test "$ticketing_system" = "linear"
        if command -q linear
            set -l issue_info (linear issue view $ticket_key 2>/dev/null)
            # Parse title from first line after "Title:"
            set title (echo "$issue_info" | grep -A1 "^Title:" | tail -1 | string trim)
            # Get description
            set description (echo "$issue_info" | grep -A100 "^Description:" | tail -n +2 | head -20)

            if test -z "$title"
                # Fallback: just use the key
                set title "$ticket_key"
            end
        else
            echo "Error: linear CLI not found"
            return 1
        end
    else
        if command -q acli
            set -l issue_info (acli jira workitem view $ticket_key 2>/dev/null)
            set title (echo "$issue_info" | grep "^Summary:" | sed 's/^Summary: *//')
            set description (echo "$issue_info" | grep -A100 "^Description:" | tail -n +2 | head -20)

            if test -z "$title"
                set title "$ticket_key"
            end
        else
            echo "Error: acli not found"
            return 1
        end
    end

    echo "Title: $title"
    echo ""

    # Transition to In Progress
    echo "Transitioning ticket to In Progress..."
    if test "$ticketing_system" = "linear"
        linear issue start $ticket_key 2>/dev/null; or true
    else
        acli jira workitem transition $ticket_key --status "In Progress" 2>/dev/null; or true
    end

    # Parse extra args for gwt-ticket
    set -l gwt_args
    set -l max_iter 20
    set -l use_devcon false

    for arg in $extra_args
        switch $arg
            case --max
                # Next iteration will grab the value
                set -a gwt_args $arg
            case --devcon
                set use_devcon true
                set -a gwt_args $arg
            case '*'
                set -a gwt_args $arg
        end
    end

    # Call gwt-ticket directly (core worktree + devcontainer + tmux + ralph-loop logic)
    gwt-ticket $ticket_key $title $description --system $ticketing_system $gwt_args
end
