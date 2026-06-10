function opencode-forkworktree --description "Launch a gwtt OpenCode worktree from an OpenCode slash command"
    set -l show_help false
    set -l source_session "$OPENCODE_SESSION_ID"
    set -l source_dir "$OPENCODE_DIR"
    set -l worktree_name ""
    set -l prompt_parts
    set -l passthrough_args
    set -l passthrough false
    set -l message_id ""
    set -l full false
    set -l session_next false
    set -l source_dir_next false
    set -l message_next false

    for arg in $argv
        if $session_next
            set source_session "$arg"
            set session_next false
            continue
        end

        if $source_dir_next
            set source_dir "$arg"
            set source_dir_next false
            continue
        end

        if $message_next
            set message_id "$arg"
            set message_next false
            continue
        end

        if $passthrough
            set -a passthrough_args "$arg"
            continue
        end

        switch $arg
            case --help -h
                set show_help true
            case --session
                set session_next true
            case --source-dir --dir
                set source_dir_next true
            case --message --message-id --from
                set message_next true
            case --full
                set full true
            case --
                set passthrough true
            case '*'
                if test -z "$worktree_name"
                    set worktree_name "$arg"
                else
                    set -a prompt_parts "$arg"
                end
        end
    end

    if $session_next
        echo "Error: --session requires an OpenCode session id"
        return 1
    end

    if $source_dir_next
        echo "Error: --source-dir requires a directory"
        return 1
    end

    if $message_next
        echo "Error: --message requires a message id"
        return 1
    end

    if $show_help; or test -z "$worktree_name"
        echo "Usage: opencode-forkworktree [--session OPENCODE_SESSION_ID] [--full|--message ID] <worktree-name> [note...] [-- gwtt-options...]"
        echo ""
        echo "Examples:"
        echo "  opencode-forkworktree auth-spike investigate the auth refactor"
        echo "  opencode-forkworktree ui-pass polish the dashboard -- --opencode-model anthropic/claude-opus-4-6"
        return 0
    end

    if test -z "$source_dir"
        set source_dir $PWD
    end

    set -l source_realpath (realpath "$source_dir" 2>/dev/null; or echo "$source_dir")
    set -l current_git_root (git -C "$PWD" rev-parse --show-toplevel 2>/dev/null | string collect)
    set -l source_git_root (git -C "$source_realpath" rev-parse --show-toplevel 2>/dev/null | string collect)

    if test -z "$source_session"; and command -q tmux
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
                    echo "Error: tmux OPENCODE_SESSION_ID belongs to a different worktree ($tmux_dir). Run /forkgwtt from OpenCode or pass --session explicitly."
                    return 1
                end
            end
            set source_session (string replace -r '^OPENCODE_SESSION_ID=' '' -- "$tmux_session_env")
        end
    end

    if test -z "$source_session"
        echo "Error: No current OpenCode session ID found. Restart OpenCode so plugins reload, then run /forkgwtt from an active OpenCode session."
        return 1
    end

    if test -n "$current_git_root" -a -n "$source_git_root" -a "$current_git_root" != "$source_git_root"
        echo "Error: source directory does not match the current git worktree ($source_realpath)."
        return 1
    end

    set -l source_pane ""
    if test -z "$message_id"; and not $full
        if not command -q tmux
            echo "Error: tmux is required for the /forkgwtt timeline picker. Use --full or --message <id> to skip the picker."
            return 1
        end

        set -l state_home (set -q XDG_STATE_HOME; and echo $XDG_STATE_HOME; or echo "$HOME/.local/state")
        set -l attach_dir "$state_home/opencode/attaches"
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
            echo "Error: Could not find the invoking OpenCode tmux pane for $source_realpath. Launch OpenCode via 'oc' inside tmux, then retry /forkgwtt."
            return 1
        end
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

    set -l note (string join ' ' -- $prompt_parts)
    set -l source_branch (git -C "$source_realpath" branch --show-current 2>/dev/null | string collect)
    set -l prompt "Fork OpenCode session '$source_session' into a fresh worktree named '$worktree_name'. Continue the selected fork session '$forked_session' in that isolated worktree."
    set prompt "$prompt Source worktree: $source_realpath."
    if test -n "$source_branch"
        set prompt "$prompt Source branch: $source_branch."
    end
    if test -n "$note"
        set prompt "$prompt User note: $note"
    end

    set -l gwtt_output (gwtt --foreground "$worktree_name" "$prompt" --no-edit --opencode-session "$forked_session" --opencode-fork-session "$source_session" --opencode-fork-source "$source_realpath" --opencode-fork-note "$note" $passthrough_args 2>&1 | string collect)
    set -l gwtt_status $pipestatus[1]
    if test -n "$gwtt_output"
        printf '%s\n' "$gwtt_output"
    end
    if test $gwtt_status -ne 0
        return $gwtt_status
    end

    set -l tmux_target ""
    for line in (string split \n -- "$gwtt_output")
        if string match -rq '^gwtt: .* → ' -- "$line"
            set tmux_target (string replace -r '^gwtt: .* → ([^ ]+).*' '$1' -- "$line")
            break
        end
    end

    if test -n "$tmux_target"; and command -q tmux
        if set -q TMUX
            tmux switch-client -t "$tmux_target" 2>/dev/null; or tmux select-window -t "$tmux_target" 2>/dev/null
        else
            tmux select-window -t "$tmux_target" 2>/dev/null
        end
        if test $status -eq 0
            echo "forkgwtt: switched to $tmux_target"
        end
    end
end
