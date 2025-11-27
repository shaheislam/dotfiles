# fe - Comprehensive file explorer with fzf
# Toggle between files and directories, multi-select, preview, and edit
function fe --description "Interactive file explorer with fzf - toggle files/dirs with ctrl-t"
    set -l initial_query "$argv"

    # Start with directory listing
    set -l mode "directories"

    # Color theme matching main fzf config
    set -l fg "#cdd6f4"
    set -l bg_highlight "#313244"
    set -l blue "#89b4fa"
    set -l cyan "#89dceb"
    set -l green "#a6e3a1"
    set -l yellow "#f9e2af"
    set -l magenta "#cba6f7"

    while true
        if test "$mode" = "directories"
            set -l selected (fd --type=d --hidden --exclude .git | \
                fzf --multi \
                    --height=80% \
                    --border=rounded \
                    --border-label=' 📁 Directories (ctrl-t: files, ctrl-o: open, enter: cd) ' \
                    --preview='eza --tree --icons --level=2 --color=always {}' \
                    --preview-window='right:70%:wrap:rounded,<120(right,50%,wrap)' \
                    --query="$initial_query" \
                    --bind='ctrl-t:reload(fd --type=f --hidden --exclude .git)+change-border-label( 📄 Files (ctrl-t: dirs, enter: edit) )' \
                    --bind='ctrl-o:execute(open {} &> /dev/tty)' \
                    --bind='enter:become(echo cd {})' \
                    --header='ctrl-t: toggle files/dirs | ctrl-o: open | ctrl-a: select all | tab: select')

            if test -n "$selected"
                # Check if user chose to cd or if we got directory selection
                if string match -q "cd *" "$selected"
                    set -l dir (string replace "cd " "" "$selected")
                    cd "$dir"
                    echo "Changed directory to: $dir"
                    return
                end
            else
                return
            end
        else
            # File mode
            set -l selected (fd --type=f --hidden --exclude .git | \
                fzf --multi \
                    --height=80% \
                    --border=rounded \
                    --border-label=' 📄 Files (ctrl-t: dirs, alt-e: edit preview, enter: edit) ' \
                    --preview='bat --color=always --style=numbers,changes --line-range=:500 {}' \
                    --preview-window='right:70%:wrap:rounded,<120(right,50%,wrap)' \
                    --query="$initial_query" \
                    --bind='ctrl-t:reload(fd --type=d --hidden --exclude .git)+change-border-label( 📁 Directories (ctrl-t: files, ctrl-o: open, enter: cd) )' \
                    --bind='alt-e:execute(nvim {} < /dev/tty > /dev/tty)' \
                    --bind='enter:become(echo {+})' \
                    --header='ctrl-t: toggle files/dirs | alt-e: edit in nvim | ctrl-a: select all | tab: select | enter: edit')

            if test -n "$selected"
                # Open files in editor
                eval $EDITOR $selected
                return
            else
                return
            end
        end
    end
end
