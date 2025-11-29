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

        # If we have ref(s), show file filter then open DiffviewOpen
        if test (count $refs) -ge 1
            set -l range_str
            if test (count $refs) -eq 1
                set range_str $refs[1]
            else
                set range_str "$refs[1]..$refs[2]"
            end

            # If paths already specified via --, use them directly
            if test (count $paths) -ge 1
                set -l diffview_cmd "DiffviewOpen $range_str -- $paths"
                echo "Opening diff: $diffview_cmd"
                nvim -c "$diffview_cmd"
                return $status
            end

            # Get list of changed files for the selection
            set -l files
            if test (count $refs) -eq 1
                set files (command git diff-tree --no-commit-id --name-only -r $refs[1] 2>/dev/null)
            else
                set files (command git diff --name-only $refs[1] $refs[2] 2>/dev/null)
            end

            # Show file filter picker
            set -l filtered_result
            if test (count $files) -gt 0
                set filtered_result (printf '%s\n' $files | \
                    fzf --multi \
                        --header="Filter files (Tab=multi, Enter=open, Ctrl-A=all)" \
                        --prompt="Filter files> " \
                        --expect=ctrl-a,enter)
            else
                set filtered_result (echo "-- No files found, Enter to open diff --" | \
                    fzf --header="No files changed" \
                        --prompt="Press Enter to open diff> " \
                        --expect=ctrl-a,enter)
            end

            # Check if fzf was cancelled
            if test $status -ne 0
                return 0
            end

            # Parse file filter output
            set -l file_lines (string split \n -- $filtered_result)
            set -l file_key $file_lines[1]
            set -l file_selection
            if test (count $file_lines) -gt 1
                set file_selection (printf '%s\n' $file_lines[2..-1] | string match -v -- '-- *')
            end

            # Build DiffviewOpen command
            set -l diffview_cmd "DiffviewOpen $range_str"
            if test "$file_key" != ctrl-a -a (count $file_selection) -gt 0
                # User selected specific files
                set -l escaped_paths
                for path in $file_selection
                    set -a escaped_paths (printf '%s' $path | string escape)
                end
                set diffview_cmd "$diffview_cmd -- "(string join ' ' $escaped_paths)
            end

            echo "Opening: $diffview_cmd"
            nvim -c "$diffview_cmd"
            return $status
        end
    end

    # Pass through to real git for all other commands
    command git $argv
end
