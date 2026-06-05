function opencode-service --description "Manage the shared OpenCode launchd server"
    set -l label com.dotfiles.opencode-serve
    set -l uid (id -u)
    set -l plist "$HOME/Library/LaunchAgents/$label.plist"
    set -l source_plist "$HOME/dotfiles/Library/LaunchAgents/$label.plist"
    set -l state_dir "$HOME/.local/state/opencode"
    set -l out_log "$state_dir/serve.out.log"
    set -l err_log "$state_dir/serve.err.log"
    set -l password_file "$state_dir/server.password"
    set -l attach_dir "$state_dir/attaches"
    set -l port (set -q OPENCODE_PORT; and echo $OPENCODE_PORT; or echo 4096)
    set -l url "http://127.0.0.1:$port"
    set -l health_timeout (set -q OPENCODE_HEALTH_TIMEOUT; and echo $OPENCODE_HEALTH_TIMEOUT; or echo 1)
    set -l cmd (string lower -- (test -n "$argv[1]"; and echo $argv[1]; or echo status))

    if test -f "$source_plist"
        mkdir -p "$HOME/Library/LaunchAgents"
        string replace -a __HOME__ "$HOME" <$source_plist | string replace -a __DOTFILES_ROOT__ "$HOME/dotfiles" >$plist
    end

    switch "$cmd"
        case start
            mkdir -p "$state_dir"
            launchctl bootstrap "gui/$uid" "$plist" 2>/dev/null; or launchctl kickstart -k "gui/$uid/$label"
        case stop
            launchctl bootout "gui/$uid/$label"
        case restart
            launchctl bootout "gui/$uid/$label" 2>/dev/null
            mkdir -p "$state_dir"
            launchctl bootstrap "gui/$uid" "$plist" 2>/dev/null; or launchctl kickstart -k "gui/$uid/$label"
        case status
            if launchctl list | string match -q "*$label*"
                echo "$label loaded"
            else
                echo "$label not loaded"
                return 1
            end

            if command -q curl; and test -s "$password_file"
                set -l password (string collect <$password_file)
                command curl -fsS --connect-timeout 0.2 --max-time "$health_timeout" -u "opencode:$password" "$url/" >/dev/null 2>/dev/null
                if test $status -eq 0
                    echo "$url healthy"
                else
                    echo "$url not responding" >&2
                    return 1
                end
            end
        case logs
            echo "stdout: $out_log"
            test -f "$out_log"; and tail -n 40 "$out_log"
            echo "stderr: $err_log"
            test -f "$err_log"; and tail -n 40 "$err_log"
        case password
            if test -s "$password_file"
                echo "$password_file"
            else
                echo "No password file yet; run 'opencode-service start'." >&2
                return 1
            end
        case clients
            if not test -d "$attach_dir"
                echo "No pane-owned OpenCode attaches registered."
                return 0
            end

            printf "%s\t%s\t%s\t%s\t%s\n" PANE PID STATE AGE CWD
            for file in "$attach_dir"/*.pid
                test -f "$file"; or continue
                set -l pane ""
                set -l pid ""
                set -l cwd ""
                set -l started ""

                while read -l line
                    set -l parts (string split -m1 = -- "$line")
                    set -l key $parts[1]
                    set -l value $parts[2]
                    switch $key
                        case pane
                            set pane "$value"
                        case pid
                            set pid "$value"
                        case cwd
                            set cwd "$value"
                        case started
                            set started "$value"
                    end
                end <$file

                set -l state missing
                if test -n "$pid"; and kill -0 "$pid" >/dev/null 2>/dev/null
                    set -l command_line (ps -p "$pid" -o command= 2>/dev/null)
                    if string match -q "*ocv attach*" -- "$command_line"; or string match -q "*opencode attach*" -- "$command_line"; or string match -q "*scripts/bin/oc*" -- "$command_line"
                        set state running
                    else
                        set state pid-reused
                    end
                end

                set -l age unknown
                if test -n "$started"; and string match -qr '^[0-9]+$' -- $started
                    set age (math (date +%s) - $started)s
                end

                printf "%s\t%s\t%s\t%s\t%s\n" (test -n "$pane"; and echo "$pane"; or basename "$file" .pid) (test -n "$pid"; and echo "$pid"; or echo -) "$state" "$age" "$cwd"
            end
        case reap
            if not test -d "$attach_dir"
                echo "No pane-owned OpenCode attaches registered."
                return 0
            end

            set -l removed 0
            set -l killed 0
            set -l kept 0

            for file in "$attach_dir"/*.pid
                test -f "$file"; or continue

                set -l pane ""
                set -l pid ""

                while read -l line
                    set -l parts (string split -m1 = -- "$line")
                    set -l key $parts[1]
                    set -l value $parts[2]
                    switch $key
                        case pane
                            set pane "$value"
                        case pid
                            set pid "$value"
                    end
                end <$file

                if test -z "$pid"; or not string match -qr '^[0-9]+$' -- "$pid"
                    rm -f -- "$file"
                    set removed (math $removed + 1)
                    continue
                end

                if not kill -0 "$pid" >/dev/null 2>/dev/null
                    rm -f -- "$file"
                    set removed (math $removed + 1)
                    continue
                end

                set -l command_line (ps -p "$pid" -o command= 2>/dev/null)
                if not string match -q "*ocv attach*" -- "$command_line"; and not string match -q "*opencode attach*" -- "$command_line"; and not string match -q "*scripts/bin/oc*" -- "$command_line"
                    rm -f -- "$file"
                    set removed (math $removed + 1)
                    continue
                end

                set -l pane_exists unknown
                if test -n "$pane"; and command -q tmux
                    if tmux list-panes -a -F '#{pane_id}' 2>/dev/null | string match -q -- "$pane"
                        set pane_exists yes
                    else
                        set pane_exists no
                    end
                end

                if test "$pane_exists" = no
                    kill "$pid" >/dev/null 2>/dev/null; or true
                    rm -f -- "$file"
                    set killed (math $killed + 1)
                    continue
                end

                set kept (math $kept + 1)
            end

            echo "reaped: removed=$removed killed=$killed kept=$kept"
        case '*'
            echo "Usage: opencode-service [start|stop|restart|status|logs|password|clients|reap]" >&2
            return 2
    end
end
