# fzf-lua generic picker - open result in nvim

function _fzf_lua_picker_edit --description "Generic picker - open in nvim"
    set -l picker $argv[1]
    set -l rest $argv[2..-1]
    set -l result (_fzf_lua_cli $picker $rest)
    if test -n "$result"
        nvim "$result"
    end
    commandline -f repaint
end
