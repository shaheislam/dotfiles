function __cache_tool_init --description "Cache tool initialization scripts for faster startup"
    # Usage: __cache_tool_init <tool_name> <init_command>
    # Example: __cache_tool_init starship "starship init fish"
    #
    # This function caches the output of tool initialization commands.
    # Cache is invalidated when tool version changes.
    # Expected improvement: ~50-100ms startup time reduction

    set -l cache_dir "$HOME/.cache/fish-init"
    mkdir -p $cache_dir

    set -l tool_name $argv[1]
    set -l init_cmd $argv[2]
    set -l cache_file "$cache_dir/$tool_name.fish"
    set -l version_file "$cache_dir/$tool_name.version"

    # Get current tool version
    set -l current_version (eval "$tool_name --version 2>/dev/null" | head -1)
    set -l cached_version ""
    test -f $version_file && set cached_version (cat $version_file)

    # Regenerate cache if version changed or cache file missing
    if test "$current_version" != "$cached_version" -o ! -f $cache_file
        eval $init_cmd > $cache_file 2>/dev/null
        echo $current_version > $version_file
    end

    # Source the cached initialization
    source $cache_file
end
