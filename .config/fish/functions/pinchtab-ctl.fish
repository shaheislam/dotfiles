# PinchTab orchestrator management wrapper
# Multi-instance Chrome automation for AI agents
#
# Usage:
#   pinchtab-ctl start       - Launch orchestrator via launchd on macOS
#   pinchtab-ctl stop        - Stop orchestrator
#   pinchtab-ctl status      - Show orchestrator and instance status
#   pinchtab-ctl logs        - Tail orchestrator logs
#   pinchtab-ctl dashboard   - Open dashboard in browser
#   pinchtab-ctl quick <url> - Quick navigate and snapshot
#   pinchtab-ctl profiles    - List named profiles
#   pinchtab-ctl launch [profile] - Launch a new instance (optional named profile)

function pinchtab-ctl --description "Manage PinchTab Chrome orchestrator"
    if not command -q pinchtab
        echo "PinchTab not installed. Run:"
        echo "  curl -fsSL https://pinchtab.com/install.sh | bash"
        return 1
    end

    set -l cmd $argv[1]
    if test -z "$cmd"
        set cmd status
    end

    set -l label com.dotfiles.pinchtab-server
    set -l uid (id -u)
    set -l plist "$HOME/Library/LaunchAgents/$label.plist"
    set -l source_plist "$HOME/dotfiles/Library/LaunchAgents/$label.plist"
    set -l state_dir "$HOME/.local/state/pinchtab"
    set -l out_log "$state_dir/server.out.log"
    set -l err_log "$state_dir/server.err.log"
    set -l legacy_log_dir "$HOME/.config/pinchtab/logs"
    set -l legacy_pid_file "$HOME/.config/pinchtab/orchestrator.pid"
    set -l port (test -n "$PINCHTAB_PORT"; and echo $PINCHTAB_PORT; or echo 9867)

    if test -f "$source_plist"
        mkdir -p "$HOME/Library/LaunchAgents"
        string replace -a __HOME__ "$HOME" <$source_plist | string replace -a __DOTFILES_ROOT__ "$HOME/dotfiles" >$plist
    end

    switch $cmd
        case start
            if test (uname) = Darwin; and test -f "$plist"
                mkdir -p "$state_dir"
                launchctl bootstrap "gui/$uid" "$plist" 2>/dev/null; or launchctl kickstart -k "gui/$uid/$label"
                echo "Orchestrator loaded ($label, port: $port)"
                return 0
            end

            # Non-macOS fallback for manual development shells.
            if test -f "$legacy_pid_file"; and kill -0 (cat "$legacy_pid_file") 2>/dev/null
                echo "Orchestrator already running (PID: "(cat "$legacy_pid_file")", port: $port)"
                return 0
            end
            set -l stale_pid (lsof -ti :$port 2>/dev/null)
            if test -n "$stale_pid"
                echo "Port $port in use by PID $stale_pid — killing"
                kill $stale_pid 2>/dev/null
                sleep 0.5
            end
            rm -f "$legacy_pid_file"

            mkdir -p "$legacy_log_dir"
            echo "Starting PinchTab orchestrator on port $port..."
            pinchtab server >"$legacy_log_dir/orchestrator.log" 2>&1 &
            set -l server_pid $last_pid
            echo $server_pid >"$legacy_pid_file"
            sleep 1

            if kill -0 $server_pid 2>/dev/null
                echo "Orchestrator started (PID: $server_pid)"
                echo "  API: http://127.0.0.1:$port"
                echo "  Dashboard: http://127.0.0.1:$port/dashboard"
            else
                echo "Orchestrator failed to start. Check: $legacy_log_dir/orchestrator.log"
                rm -f "$legacy_pid_file"
                return 1
            end

        case stop
            set -l killed false
            if test (uname) = Darwin
                launchctl bootout "gui/$uid/$label" 2>/dev/null
                if test $status -eq 0
                    echo "Orchestrator unloaded ($label)"
                    set killed true
                end
            end

            if test -f "$legacy_pid_file"
                set -l pid (cat "$legacy_pid_file")
                if kill -0 $pid 2>/dev/null
                    kill $pid
                    echo "Orchestrator stopped (PID: $pid)"
                    set killed true
                end
                rm -f "$legacy_pid_file"
            end

            # Clean up port
            set -l stale_pid (lsof -ti :$port 2>/dev/null)
            if test -n "$stale_pid"
                kill $stale_pid 2>/dev/null
                echo "Killed orphaned process on port $port (PID: $stale_pid)"
                set killed true
            end

            if test "$killed" = false
                echo "Orchestrator not running"
            end

        case status
            echo "PinchTab Status"
            echo "==============="

            # Orchestrator status
            if test (uname) = Darwin; and launchctl list | string match -q "*$label*"
                echo "Orchestrator: loaded ($label)"
                echo "  API: http://127.0.0.1:$port"
            else if test -f "$legacy_pid_file"; and kill -0 (cat "$legacy_pid_file") 2>/dev/null
                echo "Orchestrator: running (PID: "(cat "$legacy_pid_file")")"
                echo "  API: http://127.0.0.1:$port"
            else
                echo "Orchestrator: stopped"
                echo "  Start with: pinchtab-ctl start"
                return 0
            end

            # Get instance list
            set -l health (pinchtab health 2>/dev/null)
            if test $status -eq 0
                echo "  Health: OK"
            end

            # List running instances
            echo ""
            echo "Instances:"
            pinchtab instances 2>/dev/null; or echo "  (none)"

        case logs
            echo "stdout: $out_log"
            test -f "$out_log"; and tail -n 40 "$out_log"
            echo "stderr: $err_log"
            if test -f "$err_log"
                tail -n 40 "$err_log"
            else if test -f "$legacy_log_dir/orchestrator.log"
                echo "legacy: $legacy_log_dir/orchestrator.log"
                tail -n 40 "$legacy_log_dir/orchestrator.log"
            else
                echo "No PinchTab logs found"
            end

        case dashboard
            set -l url "http://127.0.0.1:$port/dashboard"
            if test (uname) = Darwin; and launchctl list | string match -q "*$label*"
                echo "Opening dashboard: $url"
                open "$url"
            else if test -f "$legacy_pid_file"; and kill -0 (cat "$legacy_pid_file") 2>/dev/null
                echo "Opening dashboard: $url"
                open "$url"
            else
                echo "Orchestrator not running. Start with: pinchtab-ctl start"
                return 1
            end

        case quick
            if test -z "$argv[2]"
                echo "Usage: pinchtab-ctl quick <url>"
                return 1
            end
            pinchtab quick $argv[2..-1]

        case profiles
            echo "PinchTab Profiles"
            echo "================="
            set -l state_dir (test -n "$PINCHTAB_STATE_DIR"; and echo $PINCHTAB_STATE_DIR; or echo "$HOME/Library/Application Support/pinchtab")
            if test -d "$state_dir/profiles"
                for profile_dir in "$state_dir/profiles"/*/
                    set -l name (basename "$profile_dir")
                    echo "  $name"
                end
            else
                echo "  (no profiles yet)"
            end

        case launch
            set -l profile_arg ""
            if test -n "$argv[2]"
                set profile_arg --profile $argv[2]
            end
            pinchtab instance launch $profile_arg

        case '*'
            echo "Usage: pinchtab-ctl [start|stop|status|logs|dashboard|quick|profiles|launch]"
            echo ""
            echo "  start          Launch orchestrator in background"
            echo "  stop           Stop orchestrator"
            echo "  status         Show orchestrator and instance status"
            echo "  logs           Tail orchestrator logs"
            echo "  dashboard      Open dashboard in browser"
            echo "  quick <url>    Quick navigate and snapshot"
            echo "  profiles       List named profiles"
            echo "  launch [name]  Launch instance (optional profile name)"
            echo ""
            echo "For direct pinchtab commands: pinchtab <command>"
            return 1
    end
end
