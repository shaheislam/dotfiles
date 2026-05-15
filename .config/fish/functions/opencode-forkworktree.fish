function opencode-forkworktree --description "Launch a gwtt OpenCode worktree from an OpenCode slash command"
    set -l show_help false
    set -l source_session "$OPENCODE_SESSION_ID"
    set -l worktree_name ""
    set -l prompt_parts
    set -l passthrough_args
    set -l passthrough false
    set -l session_next false

    for arg in $argv
        if $session_next
            set source_session "$arg"
            set session_next false
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

    if $show_help; or test -z "$worktree_name"
        echo "Usage: opencode-forkworktree [--session OPENCODE_SESSION_ID] <worktree-name> [note...] [-- gwtt-options...]"
        echo ""
        echo "Examples:"
        echo "  opencode-forkworktree auth-spike investigate the auth refactor"
        echo "  opencode-forkworktree ui-pass polish the dashboard -- --opencode-model anthropic/claude-opus-4-6"
        return 0
    end

    if test -z "$source_session"; and command -q tmux
        set -l tmux_session_env (tmux show-environment -g OPENCODE_SESSION_ID 2>/dev/null | string collect)
        if string match -q 'OPENCODE_SESSION_ID=*' -- "$tmux_session_env"
            set source_session (string replace -r '^OPENCODE_SESSION_ID=' '' -- "$tmux_session_env")
        end
    end

    if test -z "$source_session"
        echo "Error: No current OpenCode session ID found. Restart OpenCode so plugins reload, then run /gwtfork from an active OpenCode session."
        return 1
    end

    set -l prompt (string join ' ' -- $prompt_parts)
    if test -z "$prompt"
        set prompt "Fork OpenCode session '$source_session' into a fresh worktree named '$worktree_name'. Continue the conversation in that isolated worktree."
    end

    gwtt "$worktree_name" "$prompt" --no-edit --opencode-fork-session "$source_session" $passthrough_args
end
