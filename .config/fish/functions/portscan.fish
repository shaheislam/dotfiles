function portscan --description "Scan ports with nmap and fzf"
    if not test -x /opt/homebrew/bin/nmap
        echo "nmap not installed"
        return 1
    end

    echo "Enter target (IP or hostname):"
    read target

    if test -z "$target"
        echo "No target specified"
        return 1
    end

    set -l scan_types "Quick scan (-F)" "Top 100 ports" "Common ports (1-1024)" "All ports (-p-)" "Service detection (-sV)" "OS detection (-O)"

    set -l selected (printf '%s\n' $scan_types | fzf \
        --prompt="Select scan type: " \
        --height=40% \
        --border)

    switch "$selected"
        case "Quick scan*"
            sudo nmap -F $target
        case "Top 100*"
            sudo nmap --top-ports 100 $target
        case "Common ports*"
            sudo nmap -p 1-1024 $target
        case "All ports*"
            sudo nmap -p- $target
        case "Service detection*"
            sudo nmap -sV $target
        case "OS detection*"
            sudo nmap -O $target
    end
end
