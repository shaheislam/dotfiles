function tmux-main --description "Attach to tmux main, recovering from a stale default socket"
    set -l socket_path "/tmp/tmux-"(id -u)"/default"

    command tmux new-session -A -s main
    set -l tmux_status $status

    if test $tmux_status -eq 0
        return 0
    end

    # A dead default socket makes tmux report "server exited unexpectedly".
    # Clear it and retry only when the default server is actually unreachable.
    if test -S "$socket_path"
        if not command tmux ls >/dev/null 2>&1
            rm -f "$socket_path"
            command tmux new-session -A -s main
            return $status
        end
    end

    return $tmux_status
end
