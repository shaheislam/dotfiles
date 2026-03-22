function claude-warm --description "Pre-warm a named Claude session with project context for later forking"
    # Usage: claude-warm <session-name> [files/dirs...]
    #
    # Creates a named Claude session pre-loaded with specified context.
    # Fork it later with: claude-resume --fork
    # Or directly: claude --resume <session-name> --fork-session
    #
    # If no files specified, loads CLAUDE.md + architecture docs by default.

    argparse h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: claude-warm <session-name> [files/dirs...]"
        echo ""
        echo "Pre-warm a named Claude session with project context."
        echo "Fork it later with: claude-resume --fork"
        echo ""
        echo "Arguments:"
        echo "  session-name   Name for the master session"
        echo "  files/dirs     Files or directories to load as context"
        echo "                 (default: CLAUDE.md, docs/, .claude/rules/)"
        echo ""
        echo "Examples:"
        echo "  claude-warm master-context                  # Load defaults"
        echo "  claude-warm auth-base src/auth/ docs/auth.md"
        echo "  claude-warm api-review docs/ src/api/"
        echo ""
        echo "Then fork per-feature:"
        echo "  claude --resume master-context --fork-session"
        echo "  claude-resume --fork  # FZF picker"
        return 0
    end

    if test (count $argv) -lt 1
        echo "Usage: claude-warm <session-name> [files/dirs...]"
        return 1
    end

    set -l session_name $argv[1]
    set -l context_paths $argv[2..]

    # Default context if none specified
    if test (count $context_paths) -eq 0
        for default_path in CLAUDE.md .claude/CLAUDE.md docs .claude/rules
            if test -e $default_path
                set -a context_paths $default_path
            end
        end
    end

    # Build the prompt to load context
    set -l context_prompt "Read and internalize the following project context files for future work. Understand the architecture, patterns, and conventions. After reading, confirm what you've loaded."

    for ctx in $context_paths
        if test -d $ctx
            set context_prompt "$context_prompt Read all files in $ctx."
        else if test -f $ctx
            set context_prompt "$context_prompt Read $ctx."
        else
            echo "Warning: $ctx not found, skipping"
        end
    end

    echo "Pre-warming session '$session_name' with:"
    for ctx in $context_paths
        echo "  $ctx"
    end
    echo ""
    echo "Fork later with: claude --resume $session_name --fork-session"
    echo ""

    claude --name $session_name "$context_prompt"
end
