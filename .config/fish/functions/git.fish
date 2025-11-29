function git --description "Git wrapper that opens DiffviewOpen for difftool with refs"
    # Only intercept difftool subcommand
    if test (count $argv) -ge 1 -a "$argv[1]" = "difftool"
        # Parse arguments to extract refs and paths (skip options)
        set -l refs
        set -l paths
        set -l skip_next false
        set -l after_separator false

        for arg in $argv[2..-1]
            if test "$arg" = "--"
                set after_separator true
                continue
            end
            if test $after_separator = true
                # Collect paths after --
                set -a paths $arg
                continue
            end
            if test $skip_next = true
                set skip_next false
                continue
            end

            switch $arg
                case '-t' '-x' '--tool' '--extcmd'
                    set skip_next true
                    continue
                case '--tool=*' '--extcmd=*' '-t=*' '-x=*' '-*'
                    continue
            end
            set -a refs $arg
        end

        # If we have ref(s), open DiffviewOpen
        if test (count $refs) -ge 1
            set -l range_str
            if test (count $refs) -eq 1
                set range_str $refs[1]
            else
                set range_str "$refs[1]..$refs[2]"
            end

            # Build full command with paths if present
            set -l diffview_cmd "DiffviewOpen $range_str"
            if test (count $paths) -ge 1
                set diffview_cmd "$diffview_cmd -- $paths"
            end

            echo "Opening diff: $diffview_cmd"
            nvim -c "$diffview_cmd"
            return $status
        end
    end

    # Pass through to real git for all other commands
    command git $argv
end
