function fish-init-clear --description "Clear cached tool init scripts to force regeneration"
    # Usage: fish-init-clear          # clear all caches
    #        fish-init-clear thefuck  # clear specific tool cache
    #
    # Use when: tool config changed (env vars, plugins), after upgrades,
    # or if shell behavior seems stale.

    set -l cache_dir "$HOME/.cache/fish-init"

    if not test -d $cache_dir
        echo "No cache directory found at $cache_dir"
        return 0
    end

    if test (count $argv) -gt 0
        for tool in $argv
            if test -f "$cache_dir/$tool.fish"
                rm -f "$cache_dir/$tool.fish" "$cache_dir/$tool.stamp"
                echo "Cleared cache for $tool"
            else
                echo "No cache found for $tool"
            end
        end
    else
        set -l count (count $cache_dir/*.fish)
        rm -f $cache_dir/*.fish $cache_dir/*.stamp
        echo "Cleared $count cached tool init scripts"
    end

    echo "Caches will regenerate on next shell startup."
end
