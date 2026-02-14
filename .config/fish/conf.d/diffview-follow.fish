# Notify Neovim's Diffview when shell cwd changes (instant response).
# Works alongside the 2s timer polling fallback in git.lua.
#
# Discovery: Neovim sets NVIM_DIFFVIEW_SOCKET in the tmux environment
# when Diffview opens, and removes it when Diffview closes.
#
# PERF: Caches "no socket" state to avoid synchronous `tmux show-environment`
# IPC on every cd (~5-15ms). Cache is invalidated when Neovim sets the socket
# by Diffview's VimEnter/BufEnter hooks, or after 60 seconds (safety net).
function __diffview_follow_cd --on-variable PWD
    # Only act inside tmux
    set -q TMUX; or return

    # Deduplicate: skip if same path as last notification (rapid cd/pushd/popd)
    if set -q __diffview_last_pwd; and test "$PWD" = "$__diffview_last_pwd"
        return
    end
    set -g __diffview_last_pwd "$PWD"

    # PERF: Skip tmux IPC when we recently confirmed no socket exists.
    # The common case (no Diffview open) avoids the ~5-15ms tmux show-environment call.
    # Cache expires after 60s to pick up newly-opened Diffview sessions.
    if set -q __diffview_no_socket_until
        if test (date +%s) -lt "$__diffview_no_socket_until"
            return
        end
        set -e __diffview_no_socket_until
    end

    # Get Neovim socket from tmux environment (session-scoped).
    # tmux show-environment returns "VAR=value" or "-VAR" (unset marker).
    set -l raw (tmux show-environment NVIM_DIFFVIEW_SOCKET 2>/dev/null)
    or begin
        # tmux command failed or variable not set — cache negative result
        set -g __diffview_no_socket_until (math (date +%s) + 60)
        return
    end
    # Handle unset marker: "-NVIM_DIFFVIEW_SOCKET"
    if string match -q -- '-*' "$raw"
        set -g __diffview_no_socket_until (math (date +%s) + 60)
        return
    end
    set -l socket (string replace 'NVIM_DIFFVIEW_SOCKET=' '' -- $raw)
    if test -z "$socket"
        set -g __diffview_no_socket_until (math (date +%s) + 60)
        return
    end
    # Self-heal: if the socket file is gone (Neovim crashed/exited without
    # VimLeave), clear the stale tmux var so we stop checking every cd.
    if not test -S "$socket"
        tmux set-environment -u NVIM_DIFFVIEW_SOCKET 2>/dev/null
        set -g __diffview_no_socket_until (math (date +%s) + 60)
        return
    end

    # Notify Neovim via RPC with the shell's actual $PWD (fire-and-forget).
    # Passing cwd directly avoids the tmux {last} pane ambiguity — Neovim
    # would otherwise query the wrong pane when the RPC arrives.
    # Escape backslashes and double-quotes for safe Lua string embedding.
    # Backgrounded: if Neovim is busy/dead, Fish doesn't hang.
    set -l safe_pwd (string replace -a '\\' '\\\\' -- "$PWD" | string replace -a '"' '\\"')
    command nvim --server "$socket" --remote-expr "v:lua.diffview_check_pane(\"$safe_pwd\")" &>/dev/null &
    disown 2>/dev/null
end
