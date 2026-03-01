function _claude_resume_fzf_tab_complete -d "FZF-powered claude --resume tab completion with session picker"
    set -l cmd (commandline -opc)
    set -l token (commandline --current-token)

    # Detect if previous token is --resume or -r
    set -l after_resume false
    if test (count $cmd) -ge 2
        set -l last_arg $cmd[-1]
        if test "$last_arg" = --resume; or test "$last_arg" = -r
            set after_resume true
        end
    end

    if not $after_resume
        # Not in --resume context, fall back to fifc
        _fifc
        return
    end

    # Locate the session list helper script
    set -l script_path (status dirname)/../../../scripts/claude-session-list.py
    if not test -f "$script_path"
        for try_path in ~/dotfiles/scripts/claude-session-list.py ~/dotfiles-resumepicker/scripts/claude-session-list.py
            if test -f "$try_path"
                set script_path "$try_path"
                break
            end
        end
    end

    if not test -f "$script_path"
        _fifc
        return
    end

    # Generate session list - show all projects for broad selection
    set -l session_data (python3 "$script_path" 2>/dev/null)

    if test -z "$session_data"
        commandline --function repaint
        return
    end

    # Launch FZF picker
    # Format: SESSION_ID \t PROJECT_DIR \t SLUG \t AGE \t BRANCH \t PROJECT \t MESSAGE
    set -l selected (printf '%s\n' $session_data \
        | fzf \
            --exit-0 \
            --no-multi \
            -d '\t' \
            --with-nth=3.. \
            --prompt='resume ❯ ' \
            --header='  slug                           age     branch          project          message' \
            --preview="python3 '$script_path' --detail {2} {1}" \
            --preview-window=bottom:40%:wrap \
            --bind='ctrl-/:toggle-preview' \
            --query="$token" \
        | cut -f1)

    if test -n "$selected"
        commandline --replace --current-token -- "$selected"
        commandline --insert ' '
    end
    commandline --function repaint
end
