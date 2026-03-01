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

    # Compute current project dir for local scoping
    set -l cwd_encoded (string replace -a '/' '-' -- (pwd))

    set -l scope Local
    set -l query (string trim -- "$token")

    while true
        set -l session_data
        set -l script_args

        switch $scope
            case Local
                set script_args --project "$cwd_encoded"
            case Global
                # No filter — all projects
        end

        set session_data (python3 "$script_path" $script_args 2>/dev/null)

        # If local scope is empty, auto-switch to global on first try
        if test -z "$session_data"
            if test "$scope" = Local
                set scope Global
                continue
            end
            commandline --function repaint
            return
        end

        # FZF with scope switching via alt keys
        # Format: SESSION_ID \t PROJECT_DIR \t SLUG \t AGE \t BRANCH \t PROJECT \t MESSAGE
        set -l result (printf '%s\n' $session_data \
            | fzf \
                --exit-0 \
                --no-multi \
                -d '\t' \
                --with-nth=3.. \
                --print-query \
                --prompt="resume ($scope) ❯ " \
                --header='alt-l:Local  alt-g:Global                slug / age / branch / project / message' \
                --expect='alt-l,alt-g' \
                --preview="python3 '$script_path' --detail {2} {1}" \
                --preview-window=bottom:40%:wrap \
                --bind='ctrl-/:toggle-preview' \
                --query="$query")

        set -l lines (string split \n -- $result)
        set -l typed_query $lines[1]
        set -l key $lines[2]
        set -l selection $lines[3]

        # Scope change — preserve query and re-run
        switch "$key"
            case alt-l
                set scope Local
                set query "$typed_query"
                continue
            case alt-g
                set scope Global
                set query "$typed_query"
                continue
        end

        # Selection made — extract session ID (first tab-delimited field)
        if test -n "$selection"
            set -l session_id (printf '%s' "$selection" | cut -f1)
            commandline --replace --current-token -- "$session_id"
            commandline --insert ' '
        end
        break
    end
    commandline --function repaint
end
