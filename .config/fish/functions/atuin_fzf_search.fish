function atuin_fzf_search --description "Search shell history using atuin with fzf - enhanced with colors and metadata"
    # Get the current buffer content
    set -l cmd_buffer (commandline -b)

    # Start with directory-specific history
    set -l current_mode "directory"
    set -l current_dir (pwd)

    # Atuin format: time, exit, duration, directory, command (tab-separated)
    set -l atuin_format "{time}\t{exit}\t{duration}\t{directory}\t{command}"

    # AWK script for formatting with colors
    # Directory mode: no path column
    set -l awk_dir 'BEGIN {FS="\t"} {
        # Exit status with color
        status = ($2 == "0") ? "\033[32m✓\033[0m" : "\033[31m✗\033[0m"

        # Duration color coding
        dur = $3; num = dur; gsub(/[^0-9.]/, "", num)
        secs = (index(dur,"ms") > 0) ? num/1000 : (index(dur,"s") > 0) ? num+0 : 0
        if (secs < 1) dur_c = "\033[32m" dur "\033[0m"
        else if (secs < 5) dur_c = "\033[33m" dur "\033[0m"
        else dur_c = "\033[31m" dur "\033[0m"

        printf "%s  %s  %-8s  %s\n", $1, status, dur_c, $5
    }'

    # Global/Session mode: includes path column (truncated)
    set -l awk_global 'BEGIN {FS="\t"} {
        # Exit status with color
        status = ($2 == "0") ? "\033[32m✓\033[0m" : "\033[31m✗\033[0m"

        # Duration color coding
        dur = $3; num = dur; gsub(/[^0-9.]/, "", num)
        secs = (index(dur,"ms") > 0) ? num/1000 : (index(dur,"s") > 0) ? num+0 : 0
        if (secs < 1) dur_c = "\033[32m" dur "\033[0m"
        else if (secs < 5) dur_c = "\033[33m" dur "\033[0m"
        else dur_c = "\033[31m" dur "\033[0m"

        # Path truncation (keep first 8 and last 8 chars if > 20)
        path = $4
        if (length(path) > 20) path = substr(path,1,8) "..." substr(path,length(path)-7)

        printf "%s  %s  %-8s  %-20s  %s\n", $1, status, dur_c, path, $5
    }'

    # AWK for failed-only filter
    set -l awk_failed 'BEGIN {FS="\t"} $2 != "0" {
        status = "\033[31m✗\033[0m"
        dur = $3; num = dur; gsub(/[^0-9.]/, "", num)
        secs = (index(dur,"ms") > 0) ? num/1000 : (index(dur,"s") > 0) ? num+0 : 0
        if (secs < 1) dur_c = "\033[32m" dur "\033[0m"
        else if (secs < 5) dur_c = "\033[33m" dur "\033[0m"
        else dur_c = "\033[31m" dur "\033[0m"
        path = $4
        if (length(path) > 20) path = substr(path,1,8) "..." substr(path,length(path)-7)
        printf "%s  %s  %-8s  %-20s  %s\n", $1, status, dur_c, path, $5
    }'

    # Create a temporary file to store the fzf result
    set -l tmpfile (mktemp)

    # Header with all keybindings
    set -l header_dir "Mode: directory | C-d:dir C-g:global C-s:session | C-x:del C-y:copy C-e:failed C-o:edit | Enter:run →:fill"
    set -l header_global "Mode: global | C-d:dir C-g:global C-s:session | C-x:del C-y:copy C-e:failed C-o:edit | Enter:run →:fill"
    set -l header_session "Mode: session | C-d:dir C-g:global C-s:session | C-x:del C-y:copy C-e:failed C-o:edit | Enter:run →:fill"
    set -l header_failed "Mode: FAILED ONLY | C-d:dir C-g:global C-s:session | C-x:del C-y:copy C-e:all C-o:edit | Enter:run →:fill"

    # Preview command - extract and syntax highlight the command
    set -l preview_cmd "echo {} | awk -F'  ' '{print \$NF}' | fish_indent --ansi 2>/dev/null || echo {} | awk -F'  ' '{print \$NF}'"

    # Run fzf with all enhancements
    atuin search --format "$atuin_format" --cwd "$current_dir" 2>/dev/null | string replace -a "$HOME" "~" | awk "$awk_dir" | \
    fzf --ansi \
        --tac \
        --no-sort \
        --height=80% \
        --query="$cmd_buffer" \
        --header="$header_dir" \
        --expect="right" \
        --preview="$preview_cmd" \
        --preview-window="bottom:3:wrap" \
        --bind="ctrl-x:execute-silent(echo {} | awk -F'  ' '{print \$NF}' | xargs -I{} atuin search --delete --cmd-only -- {})+reload(atuin search --format '$atuin_format' --cwd '$current_dir' 2>/dev/null | string replace -a \$HOME '~' | awk '$awk_dir')" \
        --bind="ctrl-d:reload(atuin search --format '$atuin_format' --cwd '$current_dir' 2>/dev/null | string replace -a \$HOME '~' | awk '$awk_dir')+change-header($header_dir)" \
        --bind="ctrl-g:reload(atuin search --format '$atuin_format' --filter-mode global 2>/dev/null | string replace -a \$HOME '~' | awk '$awk_global')+change-header($header_global)" \
        --bind="ctrl-s:reload(atuin search --format '$atuin_format' --filter-mode session 2>/dev/null | string replace -a \$HOME '~' | awk '$awk_global')+change-header($header_session)" \
        --bind="ctrl-y:execute-silent(echo {} | awk -F'  ' '{print \$NF}' | pbcopy)" \
        --bind="ctrl-e:reload(atuin search --format '$atuin_format' --filter-mode global 2>/dev/null | string replace -a \$HOME '~' | awk '$awk_failed')+change-header($header_failed)" \
        --bind="ctrl-o:execute(echo {} | awk -F'  ' '{print \$NF}' > /tmp/atuin_edit_cmd && \${EDITOR:-nvim} /tmp/atuin_edit_cmd)+accept" \
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
            set -l selected_line $lines[2]

            # Check if we're coming from ctrl-o (edit mode)
            if test -f /tmp/atuin_edit_cmd
                set -l edited_cmd (cat /tmp/atuin_edit_cmd)
                rm -f /tmp/atuin_edit_cmd
                if test -n "$edited_cmd"
                    commandline -r -- $edited_cmd
                    commandline -f repaint
                    commandline -f execute
                end
                return
            end

            # Extract command from formatted line (last field after double-space)
            set -l selected_cmd (echo "$selected_line" | awk -F'  ' '{print $NF}')

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
            # Fallback: single line output
            set -l selected_cmd (echo "$lines[1]" | awk -F'  ' '{print $NF}')
            commandline -r -- $selected_cmd
            commandline -f repaint
            commandline -f execute
        end
    else
        # Clean up temp files
        rm -f $tmpfile /tmp/atuin_edit_cmd
        commandline -f repaint
    end
end
