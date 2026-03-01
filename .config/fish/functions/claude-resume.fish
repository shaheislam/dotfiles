function claude-resume --description "FZF picker for resuming Claude sessions"
    # Usage: claude-resume [options] [search]
    #
    # FZF-powered session picker for `claude --resume`.
    # Starts in Local scope (current dir), toggle with alt keys.
    #
    # Options:
    #   -a, --all     Start in Global scope
    #   -f, --fork    Fork session (new ID) instead of resuming in-place
    #   -h, --help    Show this help
    #
    # Aliases: cr

    argparse a/all f/fork h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: claude-resume [options] [search]"
        echo ""
        echo "FZF picker for resuming Claude sessions."
        echo ""
        echo "Options:"
        echo "  -a, --all     Start in Global scope (default: Local / current dir)"
        echo "  -f, --fork    Fork session (new ID) instead of resuming in-place"
        echo "  -h, --help    Show this help"
        echo ""
        echo "Controls:"
        echo "  alt-l         Switch to Local scope (current directory)"
        echo "  alt-g         Switch to Global scope (all projects)"
        echo "  Ctrl-/        Toggle preview pane"
        echo "  Enter         Resume selected session"
        echo ""
        echo "Aliases: cr"
        return 0
    end

    # Locate the helper script via dotfiles stow path
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
        echo "Error: claude-session-list.py not found"
        return 1
    end

    # Compute current project dir for local scoping
    set -l cwd_encoded (string replace -a '/' '-' -- (pwd))

    set -l scope Local
    if set -q _flag_all
        set scope Global
    end
    set -l query (string join ' ' -- $argv)

    while true
        set -l script_args
        switch $scope
            case Local
                set script_args --project "$cwd_encoded"
            case Global
                # No filter
        end

        set -l session_data (python3 "$script_path" $script_args 2>/dev/null)

        # Auto-switch to global if local is empty
        if test -z "$session_data"
            if test "$scope" = Local
                set scope Global
                continue
            end
            echo "No Claude sessions found"
            return 1
        end

        # FZF with scope switching
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

        # Selection made
        if test -z "$selection"
            return 0
        end

        set -l session_id (printf '%s' "$selection" | cut -f1)

        set -l resume_args --resume "$session_id"
        if set -q _flag_fork
            set -a resume_args --fork-session
        end

        echo "Resuming: $session_id"
        claude $resume_args
        return
    end
end
