function _ssh_fzf_tab_complete -d "FZF-powered ssh host tab completion"
    set -l cmd (commandline -opc)
    set -l token (commandline --current-token)

    # If typing a flag, defer to fifc
    if string match -q -- '-*' "$token"
        _fifc
        return
    end

    # If already past the host argument (e.g., ssh host command...), defer to fifc
    # Count non-flag arguments: ssh [flags...] host [command...]
    set -l non_flag_count 0
    for arg in $cmd[2..-1]
        if not string match -q -- '-*' "$arg"
            set non_flag_count (math $non_flag_count + 1)
        end
    end
    if test $non_flag_count -ge 1
        _fifc
        return
    end

    # Gather hosts from ssh config and known_hosts
    set -l hosts (complete --do-complete 'ssh ' 2>/dev/null \
        | string match -v -- '-*' \
        | awk -F'\t' '{print $1}' \
        | string match -v '*\**' \
        | sort -u)

    if test -z "$hosts"
        _fifc
        return
    end

    set -l result (printf '%s\n' $hosts \
        | fzf \
            --no-multi \
            --select-1 \
            --exit-0 \
            --scheme=path \
            --prompt='ssh ❯ ' \
            --header='SSH hosts' \
            --preview='ssh -G {} 2>/dev/null | grep -E "^(hostname|user|port|identityfile|proxycommand|proxyjump) " | sed "s/^/  /"' \
            --preview-window=right:40%:wrap \
            --query="$token")

    if test -n "$result"
        commandline --replace --current-token -- "$result"
    end
    commandline --function repaint
end
