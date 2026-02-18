function dnslookup --description "Perform DNS lookup with fzf record type selection"
    if test (count $argv) -eq 0
        echo "Usage: dnslookup <domain> [record-type]"
        return 1
    end

    set -l domain $argv[1]
    set -l record_type $argv[2]

    if test -z "$record_type"
        set -l record_types "A (IPv4 Address)" "AAAA (IPv6 Address)" "CNAME (Canonical Name)" "MX (Mail Exchange)" "NS (Name Server)" "TXT (Text Record)" "SOA (Start of Authority)" "PTR (Pointer Record)" "SRV (Service Record)" "CAA (Certification Authority)" "ALL (All Records)"
        set -l selected (printf '%s\n' $record_types | fzf \
            --prompt="Select DNS record type for $domain: " \
            --height=40% \
            --border)

        if test -z "$selected"
            return 0
        end
        set record_type (echo $selected | awk '{print $1}')
    end

    if test "$record_type" = ALL
        echo "A Records for $domain:"
        doggo $domain A
        echo ""
        echo "AAAA Records:"
        doggo $domain AAAA
        echo ""
        echo "CNAME Records:"
        doggo $domain CNAME
        echo ""
        echo "MX Records:"
        doggo $domain MX
        echo ""
        echo "TXT Records:"
        doggo $domain TXT
        echo ""
        echo "NS Records:"
        doggo $domain NS
    else
        echo "$record_type Records for $domain:"
        doggo $domain $record_type
    end
end
