function gwt-queue --description "Manage ticket queue for rate-limit-aware autonomous execution"
    # Usage: gwt-queue <command> [args...]
    #
    # Queues tickets to be dispatched via gwt-ticket when Claude Code
    # usage limits reset. A background daemon monitors the OAuth usage
    # API and auto-dispatches when capacity is available.
    #
    # Commands:
    #   add [issue-key] <title> [desc] [--opts]  Add ticket to queue
    #   list / ls                                 List queued tickets
    #   remove / rm <id>                          Remove ticket from queue
    #   clear                                     Clear all queued tickets
    #   next                                      Dispatch next ticket now
    #   start                                     Start queue daemon
    #   stop                                      Stop queue daemon
    #   status                                    Show daemon + queue + usage
    #   usage                                     Check Claude usage only
    #   log [N]                                   Show last N log lines (default: 20)
    #   help                                      Show help

    set -l queue_daemon "$HOME/dotfiles/scripts/ticket-queue/queue-daemon.sh"
    set -l usage_script "$HOME/dotfiles/scripts/ticket-queue/claude-usage.sh"

    # Fallback for dotfiles-offline worktree
    if not test -f "$queue_daemon"
        set queue_daemon "$HOME/dotfiles-offline/scripts/ticket-queue/queue-daemon.sh"
        set usage_script "$HOME/dotfiles-offline/scripts/ticket-queue/claude-usage.sh"
    end

    if not test -f "$queue_daemon"
        echo "Error: queue-daemon.sh not found"
        echo "Expected at: ~/dotfiles/scripts/ticket-queue/queue-daemon.sh"
        return 1
    end

    set -l cmd $argv[1]
    set -l rest
    if test (count $argv) -gt 1
        set rest $argv[2..]
    end

    switch "$cmd"
        case add
            if test (count $rest) -eq 0
                echo "Usage: gwt-queue add [issue-key] <title> [description] [--opts...]"
                echo ""
                echo "Options (passed to gwt-ticket):"
                echo "  --max N              Max iterations (default: 20)"
                echo "  --devcon             Use devcontainer"
                echo "  --system S           Ticketing system (linear/jira)"
                echo "  --command C          Slash command override"
                echo "  --prompt-template F  Custom prompt file"
                echo "  --prompt-prefix P    Prepend to prompt"
                echo "  --prompt-suffix S    Append to prompt"
                echo "  --mount, -m          Additional mount (repeatable)"
                echo ""
                echo "Queue-specific options:"
                echo "  --repo PATH          Git repo path (default: current dir)"
                echo "  --priority N         Priority 1-10, higher first (default: 5)"
                echo ""
                echo "Examples:"
                echo "  gwt-queue add ENG-123 \"Fix auth bug\" \"Tokens expire too early\""
                echo "  gwt-queue add \"Add dark mode\" \"Theme toggle for settings page\""
                echo "  gwt-queue add ENG-456 \"Refactor API\" --max 30 --priority 8"
                return 1
            end
            bash $queue_daemon add $rest

        case list ls
            bash $queue_daemon list

        case remove rm
            if test (count $rest) -eq 0
                echo "Usage: gwt-queue remove <ticket-id>"
                echo ""
                echo "Use 'gwt-queue list' to see ticket IDs"
                return 1
            end
            bash $queue_daemon remove $rest[1]

        case clear
            echo "This will clear all queued tickets. Continue?"
            read -l confirm -P "Clear queue? [y/N] "
            if test "$confirm" = y -o "$confirm" = Y
                bash $queue_daemon clear
            else
                echo "Cancelled"
            end

        case next
            bash $queue_daemon next

        case start
            bash $queue_daemon start

        case stop
            bash $queue_daemon stop

        case status
            bash $queue_daemon status

        case usage
            if test -x "$usage_script"
                bash $usage_script $rest
            else
                echo "Error: claude-usage.sh not found"
                return 1
            end

        case log
            set -l lines 20
            if test (count $rest) -gt 0
                set lines $rest[1]
            end
            set -l log_file "$HOME/.claude/ticket-queue.log"
            if test -f "$log_file"
                tail -n $lines $log_file
            else
                echo "No log file yet (daemon hasn't been started)"
            end

        case help --help -h ''
            echo "gwt-queue - Rate-limit-aware ticket queue for autonomous execution"
            echo ""
            echo "USAGE:"
            echo "  gwt-queue <command> [args...]"
            echo ""
            echo "COMMANDS:"
            echo "  add [key] <title> [desc] [--opts]  Queue a ticket for later execution"
            echo "  list / ls                           List all queued tickets"
            echo "  remove / rm <id>                    Remove ticket from queue"
            echo "  clear                               Clear all queued tickets"
            echo "  next                                Dispatch next ticket immediately"
            echo "  start                               Start the queue daemon"
            echo "  stop                                Stop the queue daemon"
            echo "  status                              Show daemon + queue + usage status"
            echo "  usage [--json|--wait]               Check Claude Code usage limits"
            echo "  log [N]                             Show last N log lines (default: 20)"
            echo "  help                                Show this help"
            echo ""
            echo "WORKFLOW:"
            echo "  1. Queue tickets:  gwt-queue add ENG-123 \"Fix auth\" \"Details...\""
            echo "  2. Start daemon:   gwt-queue start"
            echo "  3. Monitor:        gwt-queue status"
            echo "  4. Check log:      gwt-queue log"
            echo ""
            echo "The daemon monitors Claude usage via OAuth API and dispatches"
            echo "tickets via gwt-ticket when utilization drops below threshold."
            echo ""
            echo "CONFIGURATION (env vars):"
            echo "  QUEUE_POLL_INTERVAL  Check interval seconds (default: 300)"
            echo "  QUEUE_THRESHOLD      Max utilization % to dispatch (default: 80)"
            echo "  QUEUE_COOLDOWN       Min seconds between dispatches (default: 600)"

        case '*'
            echo "Unknown command: $cmd"
            echo "Run 'gwt-queue help' for usage"
            return 1
    end
end
