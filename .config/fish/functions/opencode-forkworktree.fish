function opencode-forkworktree --description "Launch a gwtt OpenCode worktree from an OpenCode slash command"
    set -l show_help false
    set -l source_session "$OPENCODE_SESSION_ID"
    set -l source_dir "$OPENCODE_DIR"
    set -l worktree_name ""
    set -l prompt_parts
    set -l passthrough_args
    set -l passthrough false
    set -l session_next false
    set -l source_dir_next false

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

        if $passthrough
            set -a passthrough_args "$arg"
            continue
        end

        switch $arg
            case --help -h
                set show_help true
            case --session
                set session_next true
            case --source-dir
                set source_dir_next true
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

    if $show_help; or test -z "$worktree_name"
        echo "Usage: opencode-forkworktree [--session OPENCODE_SESSION_ID] <worktree-name> [note...] [-- gwtt-options...]"
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
                    echo "Error: tmux OPENCODE_SESSION_ID belongs to a different worktree ($tmux_dir). Run /gwtfork from OpenCode or pass --session explicitly."
                    return 1
                end
            end
            set source_session (string replace -r '^OPENCODE_SESSION_ID=' '' -- "$tmux_session_env")
        end
    end

    if test -z "$source_session"
        echo "Error: No current OpenCode session ID found. Restart OpenCode so plugins reload, then run /gwtfork from an active OpenCode session."
        return 1
    end

    if test -n "$current_git_root" -a -n "$source_git_root" -a "$current_git_root" != "$source_git_root"
        echo "Error: source directory does not match the current git worktree ($source_realpath)."
        return 1
    end

    set -l note (string join ' ' -- $prompt_parts)
    set -l source_branch (git -C "$source_realpath" branch --show-current 2>/dev/null | string collect)
    set -l prompt "Fork OpenCode session '$source_session' into a fresh worktree named '$worktree_name'. Continue the conversation in that isolated worktree."
    set prompt "$prompt Source worktree: $source_realpath."
    if test -n "$source_branch"
        set prompt "$prompt Source branch: $source_branch."
    end
    if test -n "$note"
        set prompt "$prompt User note: $note"
    end

    gwtt "$worktree_name" "$prompt" --no-edit --opencode-fork-session "$source_session" --opencode-fork-source "$source_realpath" --opencode-fork-note "$note" $passthrough_args
end
