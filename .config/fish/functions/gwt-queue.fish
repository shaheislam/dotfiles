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

        case add-plan
            # Queue all tasks from a plan for rate-limit-aware dispatch
            if test (count $rest) -eq 0
                echo "Usage: gwt-queue add-plan <convoy-name> [--file tasks.md | \"Title:Desc\" ...] [--opts]"
                echo ""
                echo "Queues each task from a plan for rate-limit-aware dispatching."
                echo "Tasks are queued individually with convoy + plan context."
                echo ""
                echo "Task sources:"
                echo "  \"Title:Desc\" ...      Inline task specs"
                echo "  --file, -f FILE       Read tasks from markdown file"
                echo ""
                echo "Options forwarded to each queued gwt-ticket:"
                echo "  --template, --sub, --priority, --max, etc."
                echo ""
                echo "Examples:"
                echo "  gwt-queue add-plan auth-overhaul --file tasks.md --sub personal"
                echo "  gwt-queue add-plan refactor \"API layer:Rewrite REST\" \"DB layer:Optimize queries\""
                return 1
            end
            _gwt_queue_add_plan $rest

        case pick
            _gwt_queue_pick $queue_daemon

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
                echo Cancelled
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
                if test "$arg" = --sub
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

        case bd-ready
            # Import ready work from Beads (bd ready) into the ticket queue
            # Usage: gwt-queue bd-ready [--sub NAME] [--priority N] [--limit N] [--dry-run] [--repo PATH]
            if not command -q bd
                echo "Error: 'bd' (Beads) not found. Install with: brew install beads"
                return 1
            end
            set -l sub_name ""
            set -l priority 5
            set -l limit 10
            set -l dry_run false
            set -l repo_path (pwd)
            set -l skip_next false
            for i in (seq (count $rest))
                if $skip_next
                    set skip_next false
                    continue
                end
                set -l arg $rest[$i]
                switch $arg
                    case --sub
                        set -l ni (math $i + 1)
                        if test $ni -le (count $rest)
                            set sub_name $rest[$ni]
                            set skip_next true
                        end
                    case --priority
                        set -l ni (math $i + 1)
                        if test $ni -le (count $rest)
                            set priority $rest[$ni]
                            set skip_next true
                        end
                    case --limit
                        set -l ni (math $i + 1)
                        if test $ni -le (count $rest)
                            set limit $rest[$ni]
                            set skip_next true
                        end
                    case --repo
                        set -l ni (math $i + 1)
                        if test $ni -le (count $rest)
                            set repo_path $rest[$ni]
                            set skip_next true
                        end
                    case --dry-run
                        set dry_run true
                end
            end
            # Find ready work from Beads
            set -l bd_json (cd $repo_path && bd ready --json --limit $limit 2>/dev/null)
            if test $status -ne 0 -o -z "$bd_json"
                echo "No ready work found (run from a directory with a .beads database)"
                return 0
            end
            # Normalize to array and count
            set -l count (echo $bd_json | jq 'if type == "array" then length else 1 end' 2>/dev/null)
            if test -z "$count" -o "$count" -eq 0
                echo "No unblocked beads ready to work on"
                return 0
            end
            echo "Found $count ready bead(s):"
            echo ""
            # Queue each ready bead (use bead's own priority if no --priority override)
            # jq handles: missing fields (// fallback), non-numeric priority (tostring),
            # null values, and both array and single-object responses from bd
            echo $bd_json | jq -r '
                (if type == "array" then . else [.] end) | .[] |
                (if (.external_ref // "" | length) > 0 then .external_ref else (.id // "unknown") end) as $key |
                [$key, (.title // "Untitled"), ((.priority // 2) | tostring), ((.description // .body // "")[:200])] | @tsv
            ' 2>/dev/null | while read -l line
                set -l parts (string split \t $line)
                if test (count $parts) -lt 3
                    continue
                end
                set -l bead_key $parts[1]
                set -l bead_title $parts[2]
                set -l bead_prio $parts[3]
                set -l bead_desc $parts[4]
                # Validate priority is numeric 0-4, fallback to 2
                if not string match -qr '^[0-4]$' -- "$bead_prio"
                    set bead_prio 2
                end
                # Use explicit --priority override if provided, else bead's own priority
                set -l effective_prio $bead_prio
                if test "$priority" != 5
                    set effective_prio $priority
                end
                echo "  [$bead_key] P$effective_prio $bead_title"
                if not $dry_run
                    set -l add_args $bead_key $bead_title $bead_desc --priority $effective_prio
                    if test -n "$sub_name"
                        set add_args $add_args --sub $sub_name
                    end
                    set add_args $add_args --repo $repo_path --beads
                    bash $queue_daemon add $add_args 2>/dev/null
                    or echo "    Warning: failed to queue $bead_key"
                end
            end
            if $dry_run
                echo ""
                echo "(dry-run: no tickets queued)"
            else
                echo ""
                echo "Queued $count bead(s). Run 'gwt-queue start' to begin dispatching."
            end

        case help --help -h ''
            echo "gwt-queue - Rate-limit-aware ticket queue with multi-subscription support"
            echo ""
            echo "USAGE:"
            echo "  gwt-queue <command> [args...]"
            echo ""
            echo "COMMANDS:"
            echo "  pick                                Interactively select tickets to remove"
            echo "  add [key] <title> [desc] [--opts]  Queue a ticket for later execution"
            echo "  add-plan <name> [specs] [--opts]    Queue all tasks from a plan"
            echo "  bd-ready [--opts]                   Import ready beads into queue"
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
            echo "BD-READY OPTIONS:"
            echo "  --repo PATH     Git repo with .beads (default: current dir)"
            echo "  --limit N       Max beads to import (default: 10)"
            echo "  --priority N    Queue priority 1-10 (default: 5)"
            echo "  --sub NAME      Pin to subscription profile"
            echo "  --dry-run       Show what would be queued without queuing"
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

function _gwt_queue_add_plan --description "Queue a plan's tasks for rate-limit-aware dispatch"
    set -l queue_daemon "$HOME/dotfiles/scripts/ticket-queue/queue-daemon.sh"
    if not test -f "$queue_daemon"
        set queue_daemon "$HOME/dotfiles-offline/scripts/ticket-queue/queue-daemon.sh"
    end
    if not test -f "$queue_daemon"
        echo "Error: queue-daemon.sh not found"
        return 1
    end

    set -l convoy_name ""
    set -l task_file ""
    set -l tasks
    set -l passthrough
    set -l skip_next false

    for i in (seq (count $argv))
        if $skip_next
            set skip_next false
            continue
        end
        set -l arg $argv[$i]
        set -l next_i (math $i + 1)
        switch $arg
            case --file -f
                if test $next_i -le (count $argv)
                    set task_file $argv[$next_i]
                    set skip_next true
                end
            case '-*'
                set -a passthrough $arg
                if test $next_i -le (count $argv)
                    set -l next_val $argv[$next_i]
                    if not string match -q -- '-*' $next_val
                        set -a passthrough $next_val
                        set skip_next true
                    end
                end
            case '*'
                if test -z "$convoy_name"
                    set convoy_name $arg
                else
                    set -a tasks $arg
                end
        end
    end

    if test -z "$convoy_name"
        echo "Error: Convoy name required"
        return 1
    end

    # Parse markdown file if provided
    if test -n "$task_file"
        if not test -f "$task_file"
            echo "Error: File not found: $task_file"
            return 1
        end
        set -l parsed (awk '
            /^## / {
                if (title != "") {
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", desc)
                    if (desc == "") desc = title
                    print title ":" desc
                }
                title = substr($0, 4)
                desc = ""
                next
            }
            title != "" && /^[^#]/ && !/^[[:space:]]*$/ {
                line = $0
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
                if (line != "") {
                    if (desc != "") desc = desc " "
                    desc = desc line
                }
            }
            END {
                if (title != "") {
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", desc)
                    if (desc == "") desc = title
                    print title ":" desc
                }
            }
        ' "$task_file")
        for line in $parsed
            set -a tasks $line
        end
    end

    if test (count $tasks) -eq 0
        echo "Error: No tasks specified"
        return 1
    end

    set -l task_count (count $tasks)

    # Build plan context for all tasks
    set -l all_titles
    for i in (seq $task_count)
        set -l t (string split -m1 ':' $tasks[$i])[1]
        set -a all_titles $t
    end

    set -l task_list_text ""
    for i in (seq $task_count)
        if test -n "$task_list_text"
            set task_list_text "$task_list_text; $i. $all_titles[$i]"
        else
            set task_list_text "$i. $all_titles[$i]"
        end
    end

    echo "Queueing plan: $convoy_name ($task_count tasks)"
    echo ""

    set -l queued 0
    for i in (seq $task_count)
        set -l spec $tasks[$i]
        set -l title (string split -m1 ':' $spec)[1]
        set -l desc (string split -m1 ':' $spec)[2]
        if test -z "$desc"
            set desc $title
        end

        set -l plan_prefix "PLAN CONTEXT: You are task $i of $task_count in plan '$convoy_name'. YOUR TASK: $title. ALL TASKS IN THIS PLAN: $task_list_text. Focus ONLY on your assigned task."

        echo "  [$i] Queueing: $title"
        bash $queue_daemon add "$title" "$desc" --convoy $convoy_name --prompt-prefix "$plan_prefix" $passthrough
        and set queued (math $queued + 1)
    end

    echo ""
    echo "Queued $queued/$task_count tasks for convoy '$convoy_name'"
    echo "Start daemon: gwt-queue start"
    echo "Monitor:      gwt-queue status"
end

function _gwt_queue_pick --description "Interactive FZF picker to select and remove tickets from queue"
    set -l queue_daemon $argv[1]
    set -l queue_file "$HOME/.claude/ticket-queue.json"

    if not test -f "$queue_file"
        echo "No ticket queue found at $queue_file"
        return 1
    end

    # Parse queue JSON into FZF entries: id<TAB>priority<TAB>issue_key<TAB>title<TAB>sub
    set -l entries (python3 -c "
import json, sys
try:
    with open('$queue_file') as f:
        data = json.load(f)
    tickets = data if isinstance(data, list) else data.get('tickets', data.get('queue', []))
    for t in tickets:
        if t.get('status', 'pending') != 'pending':
            continue
        tid = t.get('id', '?')
        pri = str(t.get('priority', 5))
        key = t.get('issue_key', t.get('key', '-'))
        title = t.get('title', 'Untitled')
        sub = t.get('sub', t.get('sub_profile', '-'))
        # detail for preview (tab-separated 6th field)
        desc = t.get('description', '') or ''
        repo = t.get('repo', t.get('repo_path', '')) or ''
        added = t.get('added', t.get('created_at', '')) or ''
        detail = f'Title: {title}\nKey: {key}\nPriority: {pri}\nSub: {sub}\nRepo: {repo}\nAdded: {added}\n\nDescription:\n{desc}'
        # Escape newlines for echo -e in preview
        detail_escaped = detail.replace('\\\\', '\\\\\\\\').replace('\n', '\\\\n')
        print(f'{tid:<8s}  {pri:<3s}  {key:<12s}  {title:<40s}  {sub}\t{detail_escaped}')
except Exception as e:
    print(f'ERROR\t0\t-\t{e}\t-\t-', file=sys.stderr)
" 2>/dev/null)

    if test (count $entries) -eq 0; or test -z "$entries"
        echo "No pending tickets in queue"
        return 0
    end

    # FZF multiselect — display field 1 (padded columns), field 2 is detail for preview
    set -l selected (printf '%s\n' $entries \
        | fzf \
            --multi \
            --exit-0 \
            --tabstop=1 \
            -d '\t' \
            --with-nth=1 \
            --prompt='pick tickets to remove ❯ ' \
            --header='id        pri  key           title                                     sub' \
            --preview='echo -e {2}' \
            --preview-window=bottom:40%:wrap \
            --bind='ctrl-/:toggle-preview' \
        | cut -f1)
    # Extract ticket ID (first word) from padded line
    set selected (for line in $selected; string match -r '^\S+' -- "$line"; end)

    if test -z "$selected"
        echo "No tickets selected"
        return 0
    end

    set -l removed 0
    for tid in $selected
        echo "Removing: $tid"
        bash $queue_daemon remove "$tid" 2>/dev/null
        and set removed (math $removed + 1)
    end
    echo ""
    echo "Removed $removed ticket(s)"
end
