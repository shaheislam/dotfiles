function oc --description "Attach OpenCode TUI to the shared local server"
    set -l port (set -q OPENCODE_PORT; and echo $OPENCODE_PORT; or echo 4096)
    set -l state_home (set -q XDG_STATE_HOME; and echo $XDG_STATE_HOME; or echo "$HOME/.local/state")
    set -l password_file "$state_home/opencode/server.password"

    if not set -q OPENCODE_SERVER_PASSWORD; and test -s "$password_file"
        set -gx OPENCODE_SERVER_PASSWORD (string collect <$password_file)
    end
    set -q OPENCODE_SERVER_USERNAME; or set -gx OPENCODE_SERVER_USERNAME opencode

    command opencode attach "http://127.0.0.1:$port" --dir (pwd) $argv
end
