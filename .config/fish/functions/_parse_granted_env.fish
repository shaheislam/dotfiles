function _parse_granted_env --description "Set AWS/Granted env vars from bash output"
    for line in $argv
        set -l parts (string split -m 1 "=" $line)
        if test (count $parts) -eq 2
            set -gx $parts[1] $parts[2]
        end
    end
end
