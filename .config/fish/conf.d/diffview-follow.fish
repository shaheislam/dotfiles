# Notify Neovim's Diffview when shell cwd changes (instant response).
# Works alongside the 2s timer polling fallback in git.lua.
#
# Discovery: Neovim sets NVIM_DIFFVIEW_SOCKET in the tmux environment
# when Diffview opens, and removes it when Diffview closes.
#
# PERF: Three-tier caching to eliminate blocking IPC from the cd hot path:
#   1. Positive cache: cached socket path, validated with `test -S` (~1ms)
#   2. Negative cache: cd-counter-based (no subprocess), expires after 15 cd's
#   3. Async probe: tmux query runs in background, result consumed on next cd
#
# Previous implementation used `date +%s` for negative cache expiry (~30-50ms
# subprocess per check in Fish) and synchronous `tmux show-environment`
# (~100-240ms). This version eliminates ALL subprocesses from the hot path.
#
# Design decisions and tradeoffs:
#
# Q: Why counter-based (15 cd's) instead of time-based TTL?
# A: Time-based requires `date +%s` subprocess on every cd (~30-50ms in Fish).
#    Counter avoids all subprocesses. 15 cd's ≈ 30s at typical interactive pace.
#    Worst case (infrequent cd): DiffView discovery delayed until next counter
#    expiry, but git.lua's 2s timer provides continuous backup detection.
#
# Q: Why "consumed on next cd" instead of immediate async result delivery?
# A: Fish has no native file-watch or async callback mechanism. A prompt hook
#    would fire on every prompt (not just cd), adding overhead. The 2s timer
#    in git.lua already handles the gap — if DiffView opens, the Neovim timer
#    detects the pane within 2 seconds regardless of Fish hook timing.
#
# Q: Why not use tmux options (`show -gqv @socket`) instead of environment?
# A: Benchmarked both; tmux IPC cost is similar (~80-240ms). The async probe
#    eliminates this cost regardless of which tmux command is used.
#
# Q: What about background process cleanup?
# A: Probe uses a fixed path (/tmp/diffview-probe-$fish_pid) that is
#    overwritten by the next probe and removed on shell exit via trap.
#    Background `tmux` commands are lightweight and self-terminate.
#
# Q: How is tmux server restart handled?
# A: $TMUX contains the server socket path + session ID. A server restart
#    changes $TMUX, which invalidates the positive cache (line ~36).
#    The async probe then re-queries the new server.
function __diffview_follow_cd --on-variable PWD
    # Only act inside tmux (first check, fast guard — $TMUX is always set in tmux)
    set -q TMUX; or return

    # Deduplicate: skip if same path as last notification (rapid cd/pushd/popd)
    if set -q __diffview_last_pwd; and test "$PWD" = "$__diffview_last_pwd"
        return
    end
    set -g __diffview_last_pwd "$PWD"

    # ── Tier 1: Positive cache (socket known and valid) ──────────────────
    # Cost: ~1-3ms (Fish builtins + test -S only, no subprocess)
    # Invalidation: $TMUX change (server restart/session switch) or socket gone.
    if set -q __diffview_cached_socket; and test -n "$__diffview_cached_socket"
        if test "$TMUX" != "$__diffview_cached_tmux"
            # tmux server/session changed — cached socket is from a different server
            set -e __diffview_cached_socket
            set -e __diffview_cached_tmux
            set -g __diffview_neg_remaining 0
        else if test -S "$__diffview_cached_socket"
            # Socket still valid (test -S: exists AND is a socket file) — fire RPC
            set -l safe_pwd (string replace -a '\\' '\\\\' -- "$PWD" | string replace -a '"' '\\"')
            command nvim --server "$__diffview_cached_socket" --remote-expr "v:lua.diffview_check_pane(\"$safe_pwd\")" &>/dev/null &
            disown 2>/dev/null
            return
        else
            # Socket gone (Neovim exited) — clear cache, will re-probe below
            set -e __diffview_cached_socket
            set -e __diffview_cached_tmux
            command tmux set-environment -u NVIM_DIFFVIEW_SOCKET 2>/dev/null &
            disown 2>/dev/null
        end
    end

    # ── Tier 2: Negative cache (no socket, skip N cd's) ──────────────────
    # Cost: ~0ms (pure integer decrement, no subprocess at all)
    # Expires after 15 cd's — responsive enough for interactive use while
    # avoiding per-cd subprocess overhead. The 2s timer in git.lua provides
    # backup discovery if DiffView opens between cd's, so the shell hook
    # missing a few cd's has no user-visible effect.
    if set -q __diffview_neg_remaining; and test "$__diffview_neg_remaining" -gt 0
        set -g __diffview_neg_remaining (math "$__diffview_neg_remaining - 1")
        return
    end

    # ── Tier 3: Async probe — check for result from previous background query ──
    # If we previously launched an async tmux probe, consume its result now.
    # Note: result is "next cd" gated. The git.lua 2s timer provides immediate
    # detection independent of this hook, so the one-cd delay has no UX impact.
    if set -q __diffview_probe_file; and test -f "$__diffview_probe_file"
        set -l probe_result (command cat "$__diffview_probe_file" 2>/dev/null)
        command rm -f "$__diffview_probe_file" 2>/dev/null
        set -e __diffview_probe_file

        if test -n "$probe_result"
            # Got a result — check if it's an unset marker or valid socket
            if string match -q -- '-*' "$probe_result"
                set -g __diffview_neg_remaining 15
                return
            end
            set -l socket (string replace 'NVIM_DIFFVIEW_SOCKET=' '' -- $probe_result)
            if test -n "$socket"; and test -S "$socket"
                # Valid socket found (test -S confirms socket type) — cache and fire RPC
                set -g __diffview_cached_socket "$socket"
                set -g __diffview_cached_tmux "$TMUX"
                set -l safe_pwd (string replace -a '\\' '\\\\' -- "$PWD" | string replace -a '"' '\\"')
                command nvim --server "$socket" --remote-expr "v:lua.diffview_check_pane(\"$safe_pwd\")" &>/dev/null &
                disown 2>/dev/null
                return
            else if test -n "$socket"; and not test -S "$socket"
                # Socket path exists but file gone — clean up stale env var
                command tmux set-environment -u NVIM_DIFFVIEW_SOCKET 2>/dev/null &
                disown 2>/dev/null
            end
        end
        # No valid socket from probe — set negative cache
        set -g __diffview_neg_remaining 15
        return
    end

    # ── Launch async probe (single-flight guarded) ───────────────────────
    # Background the tmux IPC call so the shell prompt returns immediately.
    # Result will be consumed on the NEXT cd. Uses a fixed temp path per
    # Fish PID to avoid mktemp subprocess overhead.
    #
    # Single-flight guard: __diffview_probe_file is only set when we launch
    # a probe and cleared when consumed (line ~71). If already set but no
    # file exists yet, a probe is in flight — skip to prevent concurrent
    # tmux queries from rapid cd bursts.
    if set -q __diffview_probe_file
        # Probe already in flight — don't spawn another
        return
    end
    set -g __diffview_probe_file /tmp/diffview-probe-$fish_pid
    command tmux show-environment NVIM_DIFFVIEW_SOCKET >$__diffview_probe_file 2>/dev/null &
    disown 2>/dev/null
end

# Clean up probe temp file on shell exit to prevent /tmp accumulation.
# Fish EXIT event fires on normal exit; background tmux processes self-terminate.
function __diffview_cleanup --on-event fish_exit
    if set -q __diffview_probe_file
        command rm -f "$__diffview_probe_file" 2>/dev/null
    end
end
