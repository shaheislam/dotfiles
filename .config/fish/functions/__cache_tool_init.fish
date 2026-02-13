function __cache_tool_init --description "Cache tool initialization scripts for faster startup"
    # Usage: __cache_tool_init <tool_name> <init_command>
    # Example: __cache_tool_init starship "starship init fish"
    #
    # Caches tool init output, invalidated when tool binary changes (mtime check).
    # Avoids subprocess calls on cache hits for maximum startup speed.

    set -l cache_dir "$HOME/.cache/fish-init"
    set -l tool_name $argv[1]
    set -l init_cmd $argv[2]
    set -l cache_file "$cache_dir/$tool_name.fish"
    set -l stamp_file "$cache_dir/$tool_name.stamp"

    # Fast path: if cache exists, check if tool binary is newer
    if test -f $cache_file
        set -l tool_path (command -v $tool_name 2>/dev/null)
        # If tool exists and cache is newer than binary, use cache directly (no subprocess)
        if test -n "$tool_path" -a -f $stamp_file
            if test $cache_file -nt $tool_path
                source $cache_file
                return
            end
        else if test -n "$tool_path"
            # No stamp file yet but cache exists - use it, regenerate stamp
            source $cache_file
            touch $stamp_file 2>/dev/null
            return
        end
    end

    # Slow path: regenerate cache
    mkdir -p $cache_dir
    eval $init_cmd >$cache_file 2>/dev/null
    touch $stamp_file 2>/dev/null
    source $cache_file
end
