# Auto-rebuild bat cache when version changes (handles upgrades and dual installs)
# PERF: Deferred to fish_prompt event to avoid blocking shell startup (~100ms savings).
# The cache rebuild only runs once per bat version change.
if status is-interactive
    function __bat_cache_check --on-event fish_prompt
        functions -e __bat_cache_check # run once then remove
        if not type -q bat
            return
        end
        set -l cache_marker "$HOME/.cache/bat/.version"
        # Fast path: marker file exists and matches — skip bat --version call entirely
        if test -f "$cache_marker"
            set -l cached_ver (command cat "$cache_marker" 2>/dev/null)
            set -l cur_ver (bat --version 2>/dev/null | string replace 'bat ' '')
            if test "$cached_ver" = "$cur_ver"
                return
            end
        end
        # Slow path: rebuild cache
        set -l bat_version (bat --version 2>/dev/null | string replace 'bat ' '')
        bat cache --build >/dev/null 2>&1
        mkdir -p (dirname "$cache_marker")
        echo "$bat_version" >"$cache_marker"
    end
end
