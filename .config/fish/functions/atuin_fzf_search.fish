function atuin_fzf_search --description "Search shell history using atuin with fzf"
    # Get the current buffer content
    set -l cmd_buffer (commandline -b)
    
    # Define the atuin command with base options
    set -l atuin_cmd "atuin search --cmd-only"
    
    # Start with directory-specific history
    set -l current_mode "directory"
    set -l current_dir (pwd)
    
    # Run FZF with atuin
    set -l fzf_result (
        eval "$atuin_cmd --cwd '$current_dir' 2>/dev/null" | \
        fzf --tac \
            --no-sort \
            --height=80% \
            --query="$cmd_buffer" \
            --header="Mode: $current_mode | C-d: dir | C-g: global | C-s: session" \
            --bind="ctrl-d:reload($atuin_cmd --cwd '$current_dir' 2>/dev/null)+change-header(Mode: directory | C-d: dir | C-g: global | C-s: session)" \
            --bind="ctrl-g:reload($atuin_cmd 2>/dev/null)+change-header(Mode: global | C-d: dir | C-g: global | C-s: session)" \
            --bind="ctrl-s:reload($atuin_cmd --filter-mode session 2>/dev/null)+change-header(Mode: session | C-d: dir | C-g: global | C-s: session)" \
            --bind="ctrl-r:reload($atuin_cmd --cwd '$current_dir' 2>/dev/null)+change-header(Mode: directory | C-d: dir | C-g: global | C-s: session)"
    )
    
    # If user selected something, replace command line
    if test -n "$fzf_result"
        commandline -r -- $fzf_result
        commandline -f repaint
    end
end