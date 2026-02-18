function netstat-tuln --description "Show all listening ports (netstat style) with fzf"
    sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | fzf \
        --prompt="Filter network connections: " \
        --height=80% \
        --border \
        --header-lines=1 \
        --preview='echo {} | awk "{print \"Process: \" \$1 \"\\nPID: \" \$2 \"\\nPort: \" \$9}"' \
        --preview-window=down:3:wrap
end
