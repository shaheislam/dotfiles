function claude-resume --description "FZF picker for resuming Claude sessions"
    # Usage: claude-resume [options] [search]
    #
    # FZF-powered session picker for `claude --resume`.
    # By default shows sessions for the current directory.
    #
    # Options:
    #   -a, --all     Show sessions from all projects
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
        echo "  -a, --all     Show sessions from all projects (default: current dir only)"
        echo "  -f, --fork    Fork session (new ID) instead of resuming in-place"
        echo "  -h, --help    Show this help"
        echo ""
        echo "Controls:"
        echo "  Enter         Resume selected session"
        echo "  TAB           Toggle selection (multiselect)"
        echo "  Ctrl-/        Toggle preview pane"
        echo ""
        echo "Aliases: cr"
        return 0
    end

    # Locate the helper script via dotfiles stow path
    set -l script_path (status dirname)/../../../scripts/claude-session-list.py
    if not test -f "$script_path"
        # Fallback: try common dotfiles locations
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

    # Build script args
    set -l script_args
    if not set -q _flag_all
        # Filter to current project directory
        set -l cwd_encoded (string replace -a '/' '-' -- (pwd))
        set script_args --project "$cwd_encoded"
    end

    # Generate session list
    set -l session_data (python3 "$script_path" $script_args 2>/dev/null)

    if test -z "$session_data"
        if set -q _flag_all
            echo "No Claude sessions found"
        else
            echo "No sessions for "(pwd)
            echo "Use --all (-a) to search all projects"
        end
        return 1
    end

    # Build search query from remaining args
    set -l query (string join ' ' -- $argv)

    # Launch FZF picker
    # Format: SESSION_ID \t PROJECT_DIR \t SLUG \t AGE \t BRANCH \t PROJECT \t MESSAGE
    # Display columns 3-7 (slug, age, branch, project, message), extract column 1+2 for resume
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
            --query="$query" \
        | cut -f1)

    if test -z "$selected"
        return 0
    end

    # Build resume command
    set -l resume_args --resume "$selected"
    if set -q _flag_fork
        set -a resume_args --fork-session
    end

    echo "Resuming session: $selected"
    claude $resume_args
end
