# kubectl cp to pod (shortcut)
# Usage: kcpt local_path [pod:]path
#    or: kcpt  (interactive mode)
function kcpt --description "kubectl cp to pod (shortcut)"
    if test (count $argv) -eq 0
        kcp to
        return
    end

    set -l local_path $argv[1]

    if test (count $argv) -ge 2
        if string match -q "*:*" -- $argv[2]
            set -l parts (string split ":" -- $argv[2])
            set -l pod $parts[1]
            set -l remote_path $parts[2]
            kcp to $pod $local_path $remote_path
        else
            echo "Usage: kcpt local_path pod:/path"
        end
    else
        # Interactive - select pod
        kcp to "" $local_path
    end
end
