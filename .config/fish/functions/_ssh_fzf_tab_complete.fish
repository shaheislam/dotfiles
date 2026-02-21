function _ssh_fzf_tab_complete -d "FZF-powered ssh host tab completion"
    set -l cmd (commandline -opc)
    set -l token (commandline --current-token)

    # If typing a flag, defer to fifc
    if string match -q -- '-*' "$token"
        _fifc
        return
    end

    # If already past the host argument (e.g., ssh host command...), defer to fifc
    # SSH flags that take a separate argument (e.g., -p 22, -i ~/.ssh/id_rsa)
    set -l flags_with_args b c D E e F I i J L l m O o p Q R S W w
    set -l skip_next 0
    set -l non_flag_count 0
    for arg in $cmd[2..-1]
        if test $skip_next -eq 1
            set skip_next 0
            continue
        end
        if string match -q -- '-*' "$arg"
            # Check if this flag takes an argument
            set -l flag_letter (string sub -s 2 -l 1 -- "$arg")
            if test (string length -- "$arg") -eq 2; and contains -- "$flag_letter" $flags_with_args
                set skip_next 1
            end
        else
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
