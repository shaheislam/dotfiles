function atuin_fzf_search --description "Search shell history using atuin with fzf"
    # Get the current buffer content
    set -l cmd_buffer (commandline -b)

    # Format strings for display
    # Directory mode: no path (redundant when filtering by cwd)
    # Global/Session modes: include path for context
    set -l format_dir "{time} │ {command}"
    set -l format_global "{time} │ {directory} │ {command}"

    # Start with directory-specific history
    set -l current_mode "directory"
    set -l current_dir (pwd)

    # Create a temporary file to store the fzf result
    set -l tmpfile (mktemp)

    # Run fzf with explicit key bindings
    # Initial load uses directory mode (no path shown)
    atuin search --format "$format_dir" --cwd "$current_dir" 2>/dev/null | sed "s|$HOME|~|g" | \
    fzf --tac \
        --no-sort \
        --height=80% \
        --query="$cmd_buffer" \
        --header="Mode: $current_mode | C-d: dir | C-g: global | C-s: session | C-x: delete | Enter: execute | →: populate" \
        --expect="right" \
        --bind="ctrl-x:execute-silent(atuin search --delete --cmd-only -- {-1})+reload(atuin search --format '$format_dir' --cwd '$current_dir' 2>/dev/null | sed 's|$HOME|~|g')" \
        --bind="ctrl-d:reload(atuin search --format '$format_dir' --cwd '$current_dir' 2>/dev/null | sed 's|$HOME|~|g')+change-header(Mode: directory | C-d: dir | C-g: global | C-s: session | C-x: delete | Enter: execute | →: populate)" \
        --bind="ctrl-g:reload(atuin search --format '$format_global' --filter-mode global 2>/dev/null | sed 's|$HOME|~|g')+change-header(Mode: global | C-d: dir | C-g: global | C-s: session | C-x: delete | Enter: execute | →: populate)" \
        --bind="ctrl-s:reload(atuin search --format '$format_global' --filter-mode session 2>/dev/null | sed 's|$HOME|~|g')+change-header(Mode: session | C-d: dir | C-g: global | C-s: session | C-x: delete | Enter: execute | →: populate)" \
        --bind="ctrl-r:reload(atuin search --format '$format_dir' --cwd '$current_dir' 2>/dev/null | sed 's|$HOME|~|g')+change-header(Mode: directory | C-d: dir | C-g: global | C-s: session | C-x: delete | Enter: execute | →: populate)" \
        > $tmpfile

    set -l fzf_exit_status $status

    # Read the result from the temp file
    if test $fzf_exit_status -eq 0 -a -f $tmpfile
        set -l lines (cat $tmpfile | string split \n)

        # Clean up temp file
        rm -f $tmpfile

        # When using --expect, fzf outputs:
        # Line 1: The key pressed (empty if Enter)
        # Line 2: The selected item (formatted: "time │ [path │] command")
        if test (count $lines) -ge 2
            set -l key_pressed $lines[1]
            set -l selected_line $lines[2]

            # Extract just the command from the formatted line
            # Format is either "time │ command" or "time │ path │ command"
            # We want everything after the last "│ "
            set -l selected_cmd (string replace --regex '^.*│ ' '' -- "$selected_line")

            if test -n "$selected_cmd"
                commandline -r -- $selected_cmd
                commandline -f repaint

                # Execute if Enter was pressed (key_pressed is empty)
                if test -z "$key_pressed" -o "$key_pressed" = ""
                    commandline -f execute
                end
                # If right arrow was pressed, we already populated the command line
            end
        else if test (count $lines) -eq 1 -a -n "$lines[1]"
            # Fallback: single line output (shouldn't happen with --expect)
            set -l selected_cmd (string replace --regex '^.*│ ' '' -- "$lines[1]")
            commandline -r -- $selected_cmd
            commandline -f repaint
            commandline -f execute
        end
    else
        # Clean up temp file
        rm -f $tmpfile
        commandline -f repaint
    end
end
