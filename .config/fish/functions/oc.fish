function oc --description "Attach OpenCode TUI to the shared local server"
    set -l port (set -q OPENCODE_PORT; and echo $OPENCODE_PORT; or echo 4096)
    set -l url "http://127.0.0.1:$port"
    set -l label com.dotfiles.opencode-serve
    set -l state_home (set -q XDG_STATE_HOME; and echo $XDG_STATE_HOME; or echo "$HOME/.local/state")
    set -l password_file "$state_home/opencode/server.password"

    if not set -q OPENCODE_SERVER_PASSWORD; and test -s "$password_file"
        set -gx OPENCODE_SERVER_PASSWORD (string collect <$password_file)
    end
    set -q OPENCODE_SERVER_USERNAME; or set -gx OPENCODE_SERVER_USERNAME opencode

    if command -q curl
        command curl -fsS -u "$OPENCODE_SERVER_USERNAME:$OPENCODE_SERVER_PASSWORD" "$url/path" >/dev/null 2>/dev/null
        if test $status -ne 0; and command -q launchctl
            set -l uid (id -u)
            launchctl kickstart -k "gui/$uid/$label" >/dev/null 2>/dev/null; or opencode-service start >/dev/null 2>/dev/null
            for _ in 1 2 3 4 5
                command curl -fsS -u "$OPENCODE_SERVER_USERNAME:$OPENCODE_SERVER_PASSWORD" "$url/path" >/dev/null 2>/dev/null
                and break
                sleep 0.2
            end
        end
    end

    command opencode attach "$url" --dir (pwd) $argv
end
