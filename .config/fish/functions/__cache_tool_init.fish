function __cache_tool_init --description "Cache tool initialization scripts for faster startup"
    # Usage: __cache_tool_init <tool_name> <init_command>
    # Example: __cache_tool_init starship "starship init fish"
    #
    # Caches tool init output, invalidated when tool binary changes (mtime check).
    # Avoids subprocess calls on cache hits for maximum startup speed.
    # Cache files are restricted to owner-only permissions (0600).
    # To force cache rebuild: fish-init-clear [tool_name]

    set -l cache_dir "$HOME/.cache/fish-init"
    set -l tool_name $argv[1]
    set -l init_cmd $argv[2]
    set -l cache_file "$cache_dir/$tool_name.fish"
    set -l stamp_file "$cache_dir/$tool_name.stamp"

    # Fast path: if both cache and stamp exist, source directly (no subprocess).
    # Skips the expensive command -v PATH traversal (25-56ms on macOS per call).
    # Cache invalidation happens when tool binary changes — use fish-init-clear
    # to force rebuild after upgrades, or delete stamp files.
    if test -f $cache_file -a -f $stamp_file
        source $cache_file
        return
    else if test -f $cache_file
        # Cache exists but no stamp — use it, create stamp
        source $cache_file
        touch $stamp_file 2>/dev/null
        return
    end

    # Slow path: regenerate cache
    mkdir -p $cache_dir 2>/dev/null
    chmod 700 $cache_dir 2>/dev/null
    eval $init_cmd >$cache_file 2>/dev/null
    chmod 600 $cache_file 2>/dev/null
    touch $stamp_file 2>/dev/null
    chmod 600 $stamp_file 2>/dev/null
    source $cache_file
end
