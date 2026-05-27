function opencode-service --description "Manage the shared OpenCode launchd server"
    set -l label com.dotfiles.opencode-serve
    set -l uid (id -u)
    set -l plist "$HOME/Library/LaunchAgents/$label.plist"
    set -l source_plist "$HOME/dotfiles/Library/LaunchAgents/$label.plist"
    set -l state_dir "$HOME/.local/state/opencode"
    set -l out_log "$state_dir/serve.out.log"
    set -l err_log "$state_dir/serve.err.log"
    set -l password_file "$state_dir/server.password"
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
        case '*'
            echo "Usage: opencode-service [start|stop|restart|status|logs|password]" >&2
            return 2
    end
end
