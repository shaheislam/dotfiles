function opencode-forkpane --description "Fork the current OpenCode session into a tmux split pane"
    set -l show_help false
    set -l source_session "$OPENCODE_SESSION_ID"
    set -l source_dir "$OPENCODE_DIR"
    set -l orientation auto
    set -l percent 50
    set -l message_id ""
    set -l full false
    set -l session_next false
    set -l dir_next false
    set -l percent_next false
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

        if $percent_next
            set percent "$arg"
            set percent_next false
            continue
        end

        if $message_next
            set message_id "$arg"
            set message_next false
            continue
        end

        switch $arg
            case --help -h
                set show_help true
            case --session
                set session_next true
            case --dir --source-dir
                set dir_next true
            case --horizontal horizontal right h
                set orientation horizontal
            case --vertical vertical down v
                set orientation vertical
            case --percent -p
                set percent_next true
            case --message --message-id --from
                set message_next true
            case --full
                set full true
            case '*'
                if string match -qr '^[0-9]+$' -- "$arg"
                    set percent "$arg"
                else if string match -q -- '-*' "$arg"
                    echo "Error: Unknown argument '$arg'" >&2
                    return 1
                else
                    # OpenCode slash commands may pass free-form text; it is not used by this helper.
                    continue
                end
        end
    end

    if $session_next
        echo "Error: --session requires an OpenCode session id" >&2
        return 1
    end

    if $dir_next
        echo "Error: --dir requires a directory" >&2
        return 1
    end

    if $percent_next
        echo "Error: --percent requires a number" >&2
        return 1
    end

    if $message_next
        echo "Error: --message requires a message id" >&2
        return 1
    end

    if $show_help
        echo "Usage: opencode-forkpane [--session OPENCODE_SESSION_ID] [--dir PATH] [horizontal|vertical] [--percent N] [--full|--message ID]"
        echo ""
        echo "Examples:"
        echo "  opencode-forkpane"
        echo "  opencode-forkpane vertical --percent 40"
        return 0
    end

    if test -z "$source_dir"
        set source_dir $PWD
    end

    if not string match -qr '^[0-9]+$' -- "$percent"; or test "$percent" -le 0; or test "$percent" -ge 100
        echo "Error: --percent must be between 1 and 99" >&2
        return 1
    end

    if not command -q tmux
        echo "Error: tmux is required for /forkpane" >&2
        return 1
    end

    set -l source_realpath (realpath "$source_dir" 2>/dev/null; or echo "$source_dir")
    set -l current_git_root (git -C "$PWD" rev-parse --show-toplevel 2>/dev/null | string collect)
    set -l source_git_root (git -C "$source_realpath" rev-parse --show-toplevel 2>/dev/null | string collect)

    if test -z "$source_session"
        set -l tmux_session_env (tmux show-environment -g OPENCODE_SESSION_ID 2>/dev/null | string collect)
        set -l tmux_dir_env (tmux show-environment -g OPENCODE_DIR 2>/dev/null | string collect)
        set -l tmux_dir ""
        if string match -q 'OPENCODE_DIR=*' -- "$tmux_dir_env"
            set tmux_dir (string replace -r '^OPENCODE_DIR=' '' -- "$tmux_dir_env")
        end
        if string match -q 'OPENCODE_SESSION_ID=*' -- "$tmux_session_env"
            if test -n "$tmux_dir"
                set -l tmux_git_root (git -C "$tmux_dir" rev-parse --show-toplevel 2>/dev/null | string collect)
                if test -n "$current_git_root" -a -n "$tmux_git_root" -a "$current_git_root" != "$tmux_git_root"
                    echo "Error: tmux OPENCODE_SESSION_ID belongs to a different worktree ($tmux_dir). Run /forkpane from OpenCode or pass --session explicitly." >&2
                    return 1
                end
            end
            set source_session (string replace -r '^OPENCODE_SESSION_ID=' '' -- "$tmux_session_env")
        end
    end

    if test -z "$source_session"
        echo "Error: No current OpenCode session ID found. Restart OpenCode so plugins reload, then run /forkpane from an active OpenCode session." >&2
        return 1
    end

    if test -n "$current_git_root" -a -n "$source_git_root" -a "$current_git_root" != "$source_git_root"
        echo "Error: source directory does not match the current git worktree ($source_realpath)." >&2
        return 1
    end

    set -l state_home (set -q XDG_STATE_HOME; and echo $XDG_STATE_HOME; or echo "$HOME/.local/state")
    set -l attach_dir "$state_home/opencode/attaches"
    set -l source_pane ""
    set -l source_started 0

    for attach_file in "$attach_dir"/*.pid
        test -f "$attach_file"; or continue

        set -l attach_pane ""
        set -l attach_cwd ""
        set -l attach_started 0

        for line in (string split \n -- (string collect <"$attach_file"))
            if string match -q 'pane=*' -- "$line"
                set attach_pane (string replace -r '^pane=' '' -- "$line")
            else if string match -q 'cwd=*' -- "$line"
                set attach_cwd (string replace -r '^cwd=' '' -- "$line")
            else if string match -q 'started=*' -- "$line"
                set attach_started (string replace -r '^started=' '' -- "$line")
            end
        end

        test -n "$attach_pane"; and test -n "$attach_cwd"; or continue
        tmux display-message -p -t "$attach_pane" '#{pane_id}' >/dev/null 2>/dev/null; or continue

        set -l attach_realpath (realpath "$attach_cwd" 2>/dev/null; or echo "$attach_cwd")
        if test "$attach_realpath" = "$source_realpath"
            if not string match -qr '^[0-9]+$' -- "$attach_started"
                set attach_started 0
            end
            if test -z "$source_pane"; or test "$attach_started" -ge "$source_started"
                set source_pane "$attach_pane"
                set source_started "$attach_started"
            end
        end
    end

    if test -z "$source_pane"
        echo "Error: Could not find the invoking OpenCode tmux pane for $source_realpath. Launch OpenCode via 'oc' inside tmux, then retry /forkpane." >&2
        return 1
    end

    set -l split_flag -h
    if test "$orientation" = auto
        set -l dims (tmux display-message -p -t "$source_pane" '#{pane_width} #{pane_height}' 2>/dev/null | string split ' ')
        set -l pane_width $dims[1]
        set -l pane_height $dims[2]
        set -l ratio "$OPENCODE_FORKPANE_RATIO"
        if test -z "$ratio"; or not string match -qr '^[0-9]+$' -- "$ratio"
            set ratio 2
        end

        if test -n "$pane_width" -a -n "$pane_height" -a "$pane_width" -lt (math "$pane_height * $ratio")
            set split_flag -v
        end
    else if test "$orientation" = vertical
        set split_flag -v
    end

    set -l tmux_open "$HOME/dotfiles/scripts/opencode/tmux-open.sh"
    if not test -x "$tmux_open"
        echo "Error: OpenCode tmux launcher not found at $tmux_open" >&2
        return 1
    end

    set -l selected_message ""
    if test -n "$message_id"
        set selected_message "$message_id"
    else if $full
        set selected_message __FULL__
    else
        set selected_message (opencode-select-fork-message --session "$source_session" --dir "$source_realpath" --pane "$source_pane")
        set -l select_status $status
        if test $select_status -ne 0
            return $select_status
        end
    end

    set -l forked_session (opencode-fork-session-api --session "$source_session" --dir "$source_realpath" --message "$selected_message")
    set -l fork_status $status
    if test $fork_status -ne 0; or test -z "$forked_session"
        return $fork_status
    end

    set -l oc_cmd (string escape -- "$tmux_open")" -s "(string escape -- "$forked_session")"; or begin; set -l status_code \$status; echo; echo 'forkpane: OpenCode fork exited with status' \$status_code; echo 'Press enter to close this pane.'; read; exit \$status_code; end"
    set -l launch_cmd "fish -lc "(string escape -- "$oc_cmd")
    set -l fork_pane (tmux split-window -t "$source_pane" "$split_flag" -p "$percent" -c "$source_realpath" -P -F '#{pane_id}' "$launch_cmd" 2>/dev/null | string collect)
    set -l split_status $status
    if test $split_status -ne 0
        echo "Error: Failed to create fork pane from $source_pane" >&2
        return $split_status
    end

    echo "forkpane: opened fork in $fork_pane from $source_pane"
end
