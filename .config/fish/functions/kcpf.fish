# kubectl cp from pod (shortcut)
# Usage: kcpf [pod:]path [local_path]
#    or: kcpf  (interactive mode)
function kcpf --description "kubectl cp from pod (shortcut)"
    if test (count $argv) -eq 0
        kcp from
        return
    end

    # Parse pod:path format
    if string match -q "*:*" -- $argv[1]
        set -l parts (string split ":" -- $argv[1])
        set -l pod $parts[1]
        set -l remote_path $parts[2]
        set -l local_path $argv[2]
        kcp from $pod $remote_path $local_path
    else
        echo "Usage: kcpf pod:/path [local_path]"
        echo "   or: kcpf  (interactive mode)"
    end
end
