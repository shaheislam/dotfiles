function __gwt_auto_source_ports --on-variable PWD
    # Fast path: still inside the cached worktree root subtree
    if set -q __gwt_active_wt_root
        if test "$PWD" = "$__gwt_active_wt_root"; or string match -q "$__gwt_active_wt_root/*" "$PWD"
            return 0
        end
        # Left the cached worktree — unset all sourced vars
        for v in $__gwt_port_vars
            set -e $v
        end
        set -e __gwt_active_wt_root
        set -e __gwt_port_vars
    end

    # Walk up from PWD to find a .git FILE (linked worktrees have .git as a file, not a dir)
    set -l dir $PWD
    set -l wt_root ""
    while test "$dir" != /
        if test -f "$dir/.git"
            set wt_root $dir
            break
        end
        set dir (dirname $dir)
    end

    test -z "$wt_root"; and return 0
    test -f "$wt_root/.env.ports"; or return 0

    set -g __gwt_active_wt_root $wt_root
    set -g __gwt_port_vars

    for line in (grep -v '^#' "$wt_root/.env.ports" | grep '=')
        set -l parts (string split -m1 = $line)
        set -gx $parts[1] $parts[2]
        set -a __gwt_port_vars $parts[1]
    end

    if test -f "$wt_root/.env.db"
        for line in (grep -v '^#' "$wt_root/.env.db" | grep '=')
            set -l parts (string split -m1 = $line)
            set -gx $parts[1] $parts[2]
            if not contains $parts[1] $__gwt_port_vars
                set -a __gwt_port_vars $parts[1]
            end
        end
    end
end
