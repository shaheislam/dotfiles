function opencode-select-fork-message --description "Select an OpenCode fork origin from a tmux popup"
    set -l source_session ""
    set -l source_dir "$PWD"
    set -l source_pane ""
    set -l explicit_message ""
    set -l full false
    set -l session_next false
    set -l dir_next false
    set -l pane_next false
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
        if $pane_next
            set source_pane "$arg"
            set pane_next false
            continue
        end
        if $message_next
            set explicit_message "$arg"
            set message_next false
            continue
        end

        switch $arg
            case --session
                set session_next true
            case --dir --source-dir
                set dir_next true
            case --pane
                set pane_next true
            case --message --message-id --from
                set message_next true
            case --full
                set full true
            case '*'
                continue
        end
    end

    if test -z "$source_session"
        echo "Error: --session is required" >&2
        return 1
    end
    if test -z "$source_pane"
        echo "Error: --pane is required" >&2
        return 1
    end
    if test -n "$explicit_message"
        echo "$explicit_message"
        return 0
    end
    if $full
        echo __FULL__
        return 0
    end
    if not command -q jq
        echo "Error: jq is required to build the fork timeline picker" >&2
        return 1
    end
    if not command -q fzf
        echo "Error: fzf is required for the fork timeline picker. Use --full or --message <id> to skip the picker." >&2
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
    set -l messages_json (curl -fsS -u "$OPENCODE_SERVER_USERNAME:$OPENCODE_SERVER_PASSWORD" "$url/session/$source_session/message?directory=$encoded_dir" 2>/dev/null | string collect)
    if test $status -ne 0; or test -z "$messages_json"
        echo "Error: Could not load OpenCode session timeline" >&2
        return 1
    end

    set -l choices_file (mktemp)
    set -l selection_file (mktemp)
    printf '%s' "$messages_json" | jq -r '(["__FULL__", "Full session"] | @tsv), (reverse[] | select(.info.role == "user") | [.info.id, (([.parts[]? | select(.type == "text" and (.synthetic != true) and (.ignored != true)) | .text] | join(" ")) | gsub("[\r\n\t]+"; " ") | .[0:180])] | @tsv)' >"$choices_file"

    set -l popup_cmd "set -l selected (cat "(string escape -- "$choices_file")" | fzf --prompt='Fork from> ' --with-nth=2.. --delimiter='\t' --height=100%); and printf '%s\n' \$selected > "(string escape -- "$selection_file")
    tmux display-popup -E -t "$source_pane" -w 90% -h 80% "fish -lc "(string escape -- "$popup_cmd")
    set -l popup_status $status

    set -l selected ""
    if test -s "$selection_file"
        set selected (string collect <"$selection_file")
    end
    rm -f "$choices_file" "$selection_file" >/dev/null 2>/dev/null

    if test $popup_status -ne 0; or test -z "$selected"
        echo "Error: Fork origin selection cancelled" >&2
        return 130
    end

    set -l fields (string split -m1 \t -- "$selected")
    echo $fields[1]
end
