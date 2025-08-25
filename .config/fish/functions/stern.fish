function stern --description "Stern (Kubernetes log tailing) with colored logs"
    # Use stern's native color and highlighting features
    # Common patterns to highlight in logs
    command stern \
        --color=always \
        --diff-container \
        --highlight "ERROR|error|Error" \
        --highlight "WARN|warn|Warning|WARNING" \
        --highlight "INFO|info|Info" \
        --highlight "DEBUG|debug|Debug" \
        --highlight "FATAL|fatal|Fatal" \
        --highlight "TRACE|trace|Trace" \
        --highlight '\b[45]\d\d\b' \
        --highlight '\b200\b|\b201\b|\b204\b' \
        --highlight '\b404\b|\b403\b|\b401\b' \
        --highlight '\bGET\b|\bPOST\b|\bPUT\b|\bDELETE\b|\bPATCH\b' \
        $argv
end