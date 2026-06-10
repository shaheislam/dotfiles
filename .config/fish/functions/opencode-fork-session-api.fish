function opencode-fork-session-api --description "Fork an OpenCode session through the HTTP API"
    set -l source_session ""
    set -l source_dir "$PWD"
    set -l message_id ""
    set -l session_next false
    set -l dir_next false
    set -l message_next false

    for arg in $argv
        if $session_next
            set source_session "$arg"
            set session_next false
            continue
        end
        if $dir_next
            set source_dir "$arg"
            set dir_next false
            continue
        end
        if $message_next
            set message_id "$arg"
            set message_next false
            continue
        end

        switch $arg
            case --session
                set session_next true
            case --dir --source-dir
                set dir_next true
            case --message --message-id --from
                set message_next true
            case --full
                set message_id ""
            case '*'
                continue
        end
    end

    if test -z "$source_session"
        echo "Error: --session is required" >&2
        return 1
    end
    if test "$message_id" = __FULL__
        set message_id ""
    end
    if not command -q jq
        echo "Error: jq is required to fork OpenCode sessions through the API" >&2
        return 1
    end

    set -l port (set -q OPENCODE_PORT; and echo $OPENCODE_PORT; or echo 4096)
    set -l url "http://127.0.0.1:$port"
    set -l state_home (set -q XDG_STATE_HOME; and echo $XDG_STATE_HOME; or echo "$HOME/.local/state")
    set -l password_file "$state_home/opencode/server.password"

    if not set -q OPENCODE_SERVER_PASSWORD; and test -s "$password_file"
        set -gx OPENCODE_SERVER_PASSWORD (string collect <"$password_file")
    end
    set -q OPENCODE_SERVER_USERNAME; or set -gx OPENCODE_SERVER_USERNAME opencode

    set -l encoded_dir (printf '%s' "$source_dir" | jq -sRr @uri)
    set -l body "{}"
    if test -n "$message_id"
        set body (jq -cn --arg messageID "$message_id" '{messageID: $messageID}')
    end

    set -l response (curl -fsS -u "$OPENCODE_SERVER_USERNAME:$OPENCODE_SERVER_PASSWORD" -H 'Content-Type: application/json' -d "$body" "$url/session/$source_session/fork?directory=$encoded_dir" 2>/dev/null | string collect)
    if test $status -ne 0; or test -z "$response"
        echo "Error: OpenCode session fork API failed" >&2
        return 1
    end

    printf '%s' "$response" | jq -er '.id // .data.id'
end
