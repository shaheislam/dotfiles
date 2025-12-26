function atuin_fzf_search --description "Search shell history using atuin with fzf - rich preview mode"
    # Get the current buffer content
    set -l cmd_buffer (commandline -b)
    set -l current_dir (pwd)

    # Raw format: tab-separated fields
    set -l atuin_format "{time}\t{exit}\t{duration}\t{directory}\t{command}"

    # Unified AWK: prepend exit indicator to command field
    set -l awk_format 'BEGIN {FS="\t"; OFS="\t"} {
        exit_icon = ($2 == "0") ? "\033[32m✓\033[0m" : "\033[31m✗\033[0m"
        print $1, $2, $3, $4, exit_icon " " $5
    }'

    # AWK for failed-only mode
    set -l awk_failed 'BEGIN {FS="\t"; OFS="\t"} $2 != "0" {
        exit_icon = "\033[31m✗\033[0m"
        print $1, $2, $3, $4, exit_icon " " $5
    }'

    # Preview script path
    set -l preview_script "$HOME/dotfiles/.config/fish/functions/_atuin_preview.sh"

    # Tokyo Night FZF colors (no bg/preview-bg to preserve terminal transparency)
    set -l fzf_colors "--color=fg:#c0caf5,hl:#7aa2f7,fg+:#c0caf5,bg+:#283457,hl+:#bb9af7,info:#e0af68,prompt:#7dcfff,pointer:#7aa2f7,marker:#9ece6a,spinner:#7dcfff,header:#9d7cd8,preview-fg:#c0caf5"

    # Compact headers (M- = Alt key)
    set -l header_dir "DIR | C-d:dir C-g:global M-s:session | M-x:del C-y:copy C-e:failed C-o:edit | C-/:preview"
    set -l header_global "GLOBAL | C-d:dir C-g:global M-s:session | M-x:del C-y:copy C-e:failed C-o:edit | C-/:preview"
    set -l header_session "SESSION | C-d:dir C-g:global M-s:session | M-x:del C-y:copy C-e:failed C-o:edit | C-/:preview"
    set -l header_failed "FAILED | C-d:dir C-g:global M-s:session | M-x:del C-y:copy C-e:all C-o:edit | C-/:preview"

    set -l tmpfile (mktemp)

    # Run fzf with rich preview
    atuin search --format "$atuin_format" --cwd "$current_dir" 2>/dev/null | \
        string replace -a "$HOME" "~" | \
        awk "$awk_format" | \
    fzf --ansi \
        --tac \
        --no-sort \
        --height=80% \
        --query="$cmd_buffer" \
        --header="$header_dir" \
        --expect="right" \
        --delimiter='\t' \
        --with-nth=5 \
        --preview="bash '$preview_script' {}" \
        --preview-window='right,50%,wrap' \
        --preview-label=' Details ' \
        $fzf_colors \
        --bind='ctrl-/:toggle-preview' \
        --bind="alt-x:execute-silent(echo {5} | sed 's/\\x1b\\[[0-9;]*m//g' | cut -c3- | xargs -I{} atuin search --delete --cmd-only -- {})+reload(atuin search --format '$atuin_format' --cwd '$current_dir' 2>/dev/null | sed 's|'\$HOME'|~|g' | awk '$awk_format')" \
        --bind="ctrl-d:reload(atuin search --format '$atuin_format' --cwd '$current_dir' 2>/dev/null | sed 's|'\$HOME'|~|g' | awk '$awk_format')+change-header($header_dir)" \
        --bind="ctrl-g:reload(atuin search --format '$atuin_format' --filter-mode global 2>/dev/null | sed 's|'\$HOME'|~|g' | awk '$awk_format')+change-header($header_global)" \
        --bind="alt-s:reload(atuin search --format '$atuin_format' --filter-mode session 2>/dev/null | sed 's|'\$HOME'|~|g' | awk '$awk_format')+change-header($header_session)" \
        --bind="ctrl-y:execute-silent(echo {5} | sed 's/\\x1b\\[[0-9;]*m//g' | cut -c3- | pbcopy)" \
        --bind="ctrl-e:reload(atuin search --format '$atuin_format' --filter-mode global 2>/dev/null | sed 's|'\$HOME'|~|g' | awk '$awk_failed')+change-header($header_failed)" \
        --bind="ctrl-o:execute(echo {5} | sed 's/\\x1b\\[[0-9;]*m//g' | cut -c3- > /tmp/atuin_edit_cmd && \${EDITOR:-nvim} /tmp/atuin_edit_cmd)+accept" \
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
                    # Sanitize UTF-8 to prevent Rust panics on invalid bytes
                    set -l sanitized_cmd (printf '%s' "$edited_cmd" | iconv -f UTF-8 -t UTF-8//IGNORE 2>/dev/null)
                    commandline -r -- $sanitized_cmd
                    commandline -f repaint
                    commandline -f execute
                end
                return
            end

            # Extract command from field 5 (strip ANSI and icon prefix)
            # Use sed 's/^..//' instead of cut -c3- to avoid corrupting multi-byte UTF-8
            set -l selected_cmd (echo "$selected_line" | cut -f5 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^..//')
            # Sanitize UTF-8 to prevent Rust panics on invalid bytes
            set -l sanitized_cmd (printf '%s' "$selected_cmd" | iconv -f UTF-8 -t UTF-8//IGNORE 2>/dev/null)

            if test -n "$sanitized_cmd"
                commandline -r -- $sanitized_cmd
                commandline -f repaint

                # Execute if Enter was pressed (key_pressed is empty)
                if test -z "$key_pressed" -o "$key_pressed" = ""
                    commandline -f execute
                end
                # If right arrow was pressed, we already populated the command line
            end
        else if test (count $lines) -eq 1 -a -n "$lines[1]"
            # Fallback: single line output
            # Use sed 's/^..//' instead of cut -c3- to avoid corrupting multi-byte UTF-8
            set -l selected_cmd (echo "$lines[1]" | cut -f5 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^..//')
            # Sanitize UTF-8 to prevent Rust panics on invalid bytes
            set -l sanitized_cmd (printf '%s' "$selected_cmd" | iconv -f UTF-8 -t UTF-8//IGNORE 2>/dev/null)
            commandline -r -- $sanitized_cmd
            commandline -f repaint
            commandline -f execute
        end
    else
        # Clean up temp files
        rm -f $tmpfile /tmp/atuin_edit_cmd
        commandline -f repaint
    end
end
