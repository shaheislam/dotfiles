function atuin_fzf_search --description "Search shell history using atuin with fzf"
    # Get the current buffer content
    set -l cmd_buffer (commandline -b)

    # Define the atuin command with base options
    set -l atuin_cmd "atuin search --cmd-only"

    # Start with directory-specific history
    set -l current_mode "directory"
    set -l current_dir (pwd)

    # Create a temporary file to store the fzf result
    set -l tmpfile (mktemp)

    # Run fzf with explicit key bindings
    eval "$atuin_cmd --cwd '$current_dir' 2>/dev/null" | \
    fzf --tac \
        --no-sort \
        --height=80% \
        --query="$cmd_buffer" \
        --header="Mode: $current_mode | C-d: dir | C-g: global | C-s: session | C-x: delete | Enter: execute | →: populate" \
        --expect="right" \
        --bind="ctrl-x:execute-silent(atuin search --delete --cwd '$current_dir' {})+reload($atuin_cmd --cwd '$current_dir' 2>/dev/null)" \
        --bind="ctrl-d:reload($atuin_cmd --cwd '$current_dir' 2>/dev/null)+change-header(Mode: directory | C-d: dir | C-g: global | C-s: session | C-x: delete | Enter: execute | →: populate)" \
        --bind="ctrl-g:reload($atuin_cmd --filter-mode global 2>/dev/null)+change-header(Mode: global | C-d: dir | C-g: global | C-s: session | C-x: delete | Enter: execute | →: populate)" \
        --bind="ctrl-s:reload($atuin_cmd --filter-mode session 2>/dev/null)+change-header(Mode: session | C-d: dir | C-g: global | C-s: session | C-x: delete | Enter: execute | →: populate)" \
        --bind="ctrl-r:reload($atuin_cmd --cwd '$current_dir' 2>/dev/null)+change-header(Mode: directory | C-d: dir | C-g: global | C-s: session | C-x: delete | Enter: execute | →: populate)" \
        > $tmpfile

    set -l fzf_exit_status $status

    # Read the result from the temp file
    if test $fzf_exit_status -eq 0 -a -f $tmpfile
        set -l lines (cat $tmpfile | string split \n)

        # Clean up temp file
        rm -f $tmpfile

        # When using --expect, fzf outputs:
        # Line 1: The key pressed (empty if Enter)
        # Line 2: The selected item
        if test (count $lines) -ge 2
            set -l key_pressed $lines[1]
            set -l selected_cmd $lines[2]

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
            commandline -r -- $lines[1]
            commandline -f repaint
            commandline -f execute
        end
    else
        # Clean up temp file
        rm -f $tmpfile
        commandline -f repaint
    end
end
