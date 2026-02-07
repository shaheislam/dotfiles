function gwt-queue --description "Manage ticket queue for rate-limit-aware autonomous execution"
    # Usage: gwt-queue <command> [args...]
    #
    # Queues tickets to be dispatched via gwt-ticket when Claude Code
    # usage limits reset. A background daemon monitors the OAuth usage
    # API and auto-dispatches when capacity is available.
    #
    # Supports multiple subscription profiles (--sub NAME). When no sub
    # is specified, the daemon auto-selects the profile with lowest usage.
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
    #   usage [--sub NAME]                        Check Claude usage
    #   profiles                                  List subscription profiles + usage
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
                echo "  --sub NAME           Subscription profile (default: auto-select)"
                echo ""
                echo "Examples:"
                echo "  gwt-queue add ENG-123 \"Fix auth bug\" \"Tokens expire too early\""
                echo "  gwt-queue add \"Add dark mode\" \"Theme toggle\" --sub personal"
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
            set -l plist "$HOME/Library/LaunchAgents/com.dotfiles.ticket-queue.plist"
            if not test -f "$plist"
                echo "Error: LaunchAgent plist not found: $plist"
                echo "Run 'stow' from ~/dotfiles to install it"
                return 1
            end
            set -l uid (id -u)
            launchctl bootstrap gui/$uid "$plist" 2>/dev/null
            or launchctl kickstart -k gui/$uid/com.dotfiles.ticket-queue 2>/dev/null
            sleep 1
            bash $queue_daemon status

        case stop
            set -l uid (id -u)
            launchctl bootout gui/$uid/com.dotfiles.ticket-queue 2>/dev/null
            # Also delegate to daemon script for PID cleanup
            bash $queue_daemon stop

        case status
            bash $queue_daemon status

        case profiles
            bash $queue_daemon profiles

        case usage
            if not test -x "$usage_script"
                echo "Error: claude-usage.sh not found"
                return 1
            end
            # Extract --sub from rest args and convert to --config-dir
            set -l usage_args
            set -l skip_next false
            for i in (seq (count $rest))
                if $skip_next
                    set skip_next false
                    continue
                end
                set -l arg $rest[$i]
                if test "$arg" = "--sub"
                    set -l next_i (math $i + 1)
                    if test $next_i -le (count $rest)
                        set -l sub_name $rest[$next_i]
                        set -a usage_args --config-dir "$HOME/.claude-$sub_name"
                        set skip_next true
                    else
                        echo "Error: --sub requires a profile name"
                        return 1
                    end
                else
                    set -a usage_args $arg
                end
            end
            bash $usage_script $usage_args

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
            echo "gwt-queue - Rate-limit-aware ticket queue with multi-subscription support"
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
            echo "  usage [--sub NAME] [--json|--wait]  Check Claude Code usage limits"
            echo "  profiles                            List subscription profiles + usage"
            echo "  log [N]                             Show last N log lines (default: 20)"
            echo "  help                                Show this help"
            echo ""
            echo "SUBSCRIPTION PROFILES:"
            echo "  --sub NAME on 'add' pins a ticket to a specific subscription."
            echo "  Without --sub, the daemon auto-dispatches to whichever profile"
            echo "  has the lowest utilization (smart multi-sub dispatching)."
            echo ""
            echo "WORKFLOW:"
            echo "  1. Set up profiles: claude-sub setup personal"
            echo "  2. Queue tickets:   gwt-queue add ENG-123 \"Fix auth\" --sub personal"
            echo "  3. Or auto-route:   gwt-queue add \"Fix auth\" \"Details...\""
            echo "  4. Start daemon:    gwt-queue start"
            echo "  5. Monitor:         gwt-queue status"
            echo "  6. Check profiles:  gwt-queue profiles"
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
