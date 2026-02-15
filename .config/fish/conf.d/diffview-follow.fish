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
# Design notes:
# - Counter-based cache (15 cd's) is a compromise: responsive enough for
#   interactive use, avoids subprocess on every cd. The 2s timer in git.lua
#   provides backup discovery for DiffView that opens between cd's.
# - Async probe uses single-flight guard (__diffview_probe_file set only
#   when no probe is pending) to prevent concurrent tmux queries.
# - Stale probe files are cleaned up via fixed path per fish PID.
function __diffview_follow_cd --on-variable PWD
    # Only act inside tmux
    set -q TMUX; or return

    # Deduplicate: skip if same path as last notification (rapid cd/pushd/popd)
    if set -q __diffview_last_pwd; and test "$PWD" = "$__diffview_last_pwd"
        return
    end
    set -g __diffview_last_pwd "$PWD"

    # ── Tier 1: Positive cache (socket known and valid) ──────────────────
    # Cost: ~1-3ms (Fish builtins + test -S only, no subprocess)
    if set -q __diffview_cached_socket; and test -n "$__diffview_cached_socket"
        if test "$TMUX" != "$__diffview_cached_tmux"
            # tmux server/session changed — cached socket is from a different session
            set -e __diffview_cached_socket
            set -e __diffview_cached_tmux
            set -g __diffview_neg_remaining 0
        else if test -S "$__diffview_cached_socket"
            # Socket still valid — fire RPC and return
            set -l safe_pwd (string replace -a '\\' '\\\\' -- "$PWD" | string replace -a '"' '\\"')
            command nvim --server "$__diffview_cached_socket" --remote-expr "v:lua.diffview_check_pane(\"$safe_pwd\")" &>/dev/null &
            disown 2>/dev/null
            return
        else
            # Socket gone — clear cache, will re-probe below
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
    # backup discovery if DiffView opens between cd's.
    if set -q __diffview_neg_remaining; and test "$__diffview_neg_remaining" -gt 0
        set -g __diffview_neg_remaining (math "$__diffview_neg_remaining - 1")
        return
    end

    # ── Tier 3: Async probe — check for result from previous background query ──
    # If we previously launched an async tmux probe, consume its result now.
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
                # Valid socket found — cache it and fire RPC
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
    # a probe and cleared when consumed. If already set, a probe is pending
    # (file not yet written) — skip to avoid concurrent tmux queries.
    if set -q __diffview_probe_file
        # Probe already in flight — don't spawn another
        return
    end
    set -g __diffview_probe_file /tmp/diffview-probe-$fish_pid
    command tmux show-environment NVIM_DIFFVIEW_SOCKET >$__diffview_probe_file 2>/dev/null &
    disown 2>/dev/null
end
