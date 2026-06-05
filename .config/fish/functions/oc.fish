function oc --description "Attach OpenCode TUI to the shared local server"
    set -l port (set -q OPENCODE_PORT; and echo $OPENCODE_PORT; or echo 4096)
    set -l url "http://127.0.0.1:$port"
    set -l label com.dotfiles.opencode-serve
    set -l state_home (set -q XDG_STATE_HOME; and echo $XDG_STATE_HOME; or echo "$HOME/.local/state")
    set -l password_file "$state_home/opencode/server.password"
    set -l health_timeout (set -q OPENCODE_HEALTH_TIMEOUT; and echo $OPENCODE_HEALTH_TIMEOUT; or echo 1)

    if not set -q OPENCODE_SERVER_PASSWORD; and test -s "$password_file"
        set -gx OPENCODE_SERVER_PASSWORD (string collect <$password_file)
    end
    set -q OPENCODE_SERVER_USERNAME; or set -gx OPENCODE_SERVER_USERNAME opencode

    if command -q curl
        command curl -fsS --connect-timeout 0.2 --max-time "$health_timeout" -u "$OPENCODE_SERVER_USERNAME:$OPENCODE_SERVER_PASSWORD" "$url/" >/dev/null 2>/dev/null
        if test $status -ne 0; and command -q launchctl
            set -l uid (id -u)
            launchctl kickstart -k "gui/$uid/$label" >/dev/null 2>/dev/null; or opencode-service start >/dev/null 2>/dev/null
            set -l healthy 0
            for _ in 1 2 3 4 5
                command curl -fsS --connect-timeout 0.2 --max-time "$health_timeout" -u "$OPENCODE_SERVER_USERNAME:$OPENCODE_SERVER_PASSWORD" "$url/" >/dev/null 2>/dev/null
                if test $status -eq 0
                    set healthy 1
                    break
                end
                sleep 0.2
            end
            if test $healthy -eq 0
                echo "OpenCode shared server is not responding at $url after restart." >&2
                echo "Run `opencode-service logs` or `opencode-service restart` for details." >&2
                return 1
            end
        end
    end

    command opencode attach "$url" --dir (pwd) $argv
end
