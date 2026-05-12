# Gap-only grc integration. Do not source upstream grc.fish here: it aliases
# commands already handled by eza, bat, splash, stern, kubecolor, doggo, or gping.
if status is-interactive; and command -q grc
    function __grc_gap_alias --argument-names cmd
        if command -q $cmd
            alias $cmd="grc --colour=auto $cmd"
        end
    end

    set -l grc_gap_commands \
        ps stat df diff \
        netstat ss traceroute traceroute6 ifconfig lsof whois tcpdump nmap \
        uptime w who last lastlog \
        iostat sar vmstat free \
        lsblk lspci lsmod lsattr blkid findmnt showmount sensors id

    for cmd in $grc_gap_commands
        __grc_gap_alias $cmd
    end

    functions -e __grc_gap_alias
end
