# fzf-lua CLI base helper function
# Invokes fzf-lua pickers from the command line via nvim -l
# Output is JSON - piped through jq to extract paths
#
# NOTE: Fish requires one function per file for autoloading.
# Helper functions are in separate files:
#   _fzf_lua_zoxide.fish, _fzf_lua_files_edit.fish, etc.

function _fzf_lua_cli --description "Invoke fzf-lua CLI picker and extract path"
    # Find fzf-lua CLI script path
    set -l cli_path ""

    # Check lazy.nvim path first (most common)
    if test -n "$XDG_DATA_HOME"
        set cli_path "$XDG_DATA_HOME/nvim/lazy/fzf-lua/scripts/cli.lua"
    end

    if test -z "$cli_path" -o ! -f "$cli_path"
        set cli_path "$HOME/.local/share/nvim/lazy/fzf-lua/scripts/cli.lua"
    end

    # Fallback to packer path
    if test ! -f "$cli_path"
        set cli_path "$HOME/.local/share/nvim/site/pack/packer/start/fzf-lua/scripts/cli.lua"
    end

    if test ! -f "$cli_path"
        echo "Error: fzf-lua CLI script not found" >&2
        echo "Expected at: ~/.local/share/nvim/lazy/fzf-lua/scripts/cli.lua" >&2
        return 1
    end

    # Run picker - CLI profile outputs plain text paths to stdout (not JSON)
    nvim -l "$cli_path" $argv </dev/tty
end
