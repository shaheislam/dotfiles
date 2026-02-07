# Auto-rebuild bat cache when version changes (handles upgrades and dual installs)
if status is-interactive && command -q bat
    set -l bat_version (bat --version 2>/dev/null | string replace 'bat ' '')
    set -l cache_marker "$HOME/.cache/bat/.version"
    if not test -f "$cache_marker"; or test (cat "$cache_marker" 2>/dev/null) != "$bat_version"
        bat cache --build >/dev/null 2>&1
        mkdir -p (dirname "$cache_marker")
        echo "$bat_version" > "$cache_marker"
    end
end
