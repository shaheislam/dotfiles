# fzf-lua files picker - insert path into command line

function _fzf_lua_files_insert --description "Files picker - insert into command line"
    set -l result (_fzf_lua_cli files $argv)
    if test -n "$result"
        commandline -i -- (string escape -- $result)
    end
    commandline -f repaint
end
