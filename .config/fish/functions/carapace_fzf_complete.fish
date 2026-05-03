function carapace_fzf_complete --description "Use FZF to select from Carapace completions"
    if not command -q carapace; or not command -q fzf
        return 1
    end

    # Get the current command line
    set -l cmd (commandline -p)
    set -l cursor_pos (commandline -C)
    
    # Get the token at cursor
    set -l token (commandline -t)
    
    # Get completions from carapace
    # We need to properly format the command for carapace
    set -l completions
    
    # Try to get completions using carapace's fish integration
    if command -q carapace
        # Get the completions by simulating what would happen with tab completion
        set completions (complete -C"$cmd")
        
        # If no completions from complete, try direct carapace call
        if test (count $completions) -eq 0
            # Parse the command line to get the current command and position
            set -l cmd_parts (commandline -poc)
            if test (count $cmd_parts) -gt 0
                # Build the completion request for carapace
                set -l comp_line (string join ' ' $cmd_parts)
                set completions (carapace $cmd_parts[1] fish | string split '\n' | string match -v '^$')
            end
        end
    end
    
    # If we have completions, show them in fzf
    if test (count $completions) -gt 0
        # Format completions for display in fzf
        # Extract just the completion text (first column if tab-separated)
        set -l formatted_completions
        for comp in $completions
            # Handle tab-separated completions (word\tdescription format)
            set -l parts (string split \t $comp)
            if test (count $parts) -gt 1
                # If there's a description, show both but complete only the first part
                set -a formatted_completions "$parts[1]\t$parts[2]"
            else
                # Just the completion without description
                set -a formatted_completions $comp
            end
        end
        
        # Use fzf to select from completions
        set -l selected (printf '%s\n' $formatted_completions | \
            fzf --height=40% \
                --reverse \
                --select-1 \
                --exit-0 \
                --prompt="Complete> " \
                --preview-window=right:50%:hidden \
                --bind='ctrl-/:toggle-preview' \
                --header='Press Ctrl-/ to toggle preview' \
                --ansi)
        
        # If user selected something, insert it
        if test -n "$selected"
            # Extract just the completion part (before tab if present)
            set -l completion_text (string split \t $selected)[1]
            
            # Replace the current token with the selection
            if test -n "$token"
                commandline -t "$completion_text "
            else
                commandline -i "$completion_text "
            end
        end
    else
        return 1
    end
    
    # Repaint the command line
    commandline -f repaint
end
