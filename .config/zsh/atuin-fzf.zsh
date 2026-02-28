#!/usr/bin/env zsh

# FZF-Atuin integration for Zsh
atuin-fzf-widget() {
    local selected
    local current_buffer="${LBUFFER}"
    local current_dir="${PWD}"
    local atuin_fmt='{exit}\t{directory}\t{command}'
    local awk_fmt='BEGIN {FS="\t"; OFS="\t"} {
        cmd = $3; for (i=4; i<=NF; i++) cmd = cmd " " $i
        icon = ($1 == "0") ? "\033[32m✓\033[0m" : "\033[31m✗\033[0m"
        print icon " " cmd, "\033[2m" $2 "\033[0m"
    }'

    # Run atuin with fzf - default: GLOBAL mode showing directories
    selected=$(
        atuin search --format "${atuin_fmt}" --filter-mode global 2>/dev/null | \
        sed "s|${HOME}|~|g" | awk "${awk_fmt}" | \
        fzf --ansi --tac \
            --scheme=history \
            --tiebreak=index \
            --no-multi \
            --height=80% \
            --query="${current_buffer}" \
            --delimiter=$'\t' \
            --with-nth=1..2 \
            --nth=1 \
            --header="GLOBAL | C-d: dir | C-g: global | C-s: session" \
            --bind="ctrl-d:reload(atuin search --format '${atuin_fmt}' --cwd '${current_dir}' 2>/dev/null | sed 's|${HOME}|~|g' | awk '${awk_fmt}')+change-header(DIR | C-d: dir | C-g: global | C-s: session)" \
            --bind="ctrl-g:reload(atuin search --format '${atuin_fmt}' --filter-mode global 2>/dev/null | sed 's|${HOME}|~|g' | awk '${awk_fmt}')+change-header(GLOBAL | C-d: dir | C-g: global | C-s: session)" \
            --bind="ctrl-s:reload(atuin search --format '${atuin_fmt}' --filter-mode session 2>/dev/null | sed 's|${HOME}|~|g' | awk '${awk_fmt}')+change-header(SESSION | C-d: dir | C-g: global | C-s: session)"
    )

    local ret=$?

    if [[ -n $selected ]]; then
        # Extract command: take field 1, strip ANSI codes and icon prefix
        LBUFFER=$(echo "$selected" | cut -f1 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^..//')
    fi

    zle reset-prompt
    return $ret
}

# Create the widget
zle -N atuin-fzf-widget

# Bind to Ctrl-R
bindkey '^R' atuin-fzf-widget
