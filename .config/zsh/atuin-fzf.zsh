#!/usr/bin/env zsh

# FZF-Atuin integration for Zsh
atuin-fzf-widget() {
    local selected
    local current_buffer="${LBUFFER}"
    local current_dir="${PWD}"
    
    # Run atuin with fzf
    selected=$(
        atuin search --cmd-only --cwd "${current_dir}" 2>/dev/null | \
        fzf --tac \
            --no-sort \
            --height=80% \
            --query="${current_buffer}" \
            --header="Mode: directory | C-d: dir | C-g: global | C-s: session" \
            --bind="ctrl-d:reload(atuin search --cmd-only --cwd '${current_dir}' 2>/dev/null)+change-header(Mode: directory | C-d: dir | C-g: global | C-s: session)" \
            --bind="ctrl-g:reload(atuin search --cmd-only 2>/dev/null)+change-header(Mode: global | C-d: dir | C-g: global | C-s: session)" \
            --bind="ctrl-s:reload(atuin search --cmd-only --filter-mode session 2>/dev/null)+change-header(Mode: session | C-d: dir | C-g: global | C-s: session)" \
            --bind="ctrl-r:reload(atuin search --cmd-only --cwd '${current_dir}' 2>/dev/null)+change-header(Mode: directory | C-d: dir | C-g: global | C-s: session)"
    )
    
    local ret=$?
    
    if [[ -n $selected ]]; then
        LBUFFER="${selected}"
    fi
    
    zle reset-prompt
    return $ret
}

# Create the widget
zle -N atuin-fzf-widget

# Bind to Ctrl-R
bindkey '^R' atuin-fzf-widget