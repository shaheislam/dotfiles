function obsidian-session-sync --description "Synthesize Claude session into Obsidian documentation"
    argparse 'w/worktree=' 'c/cwd=' 't/ticket=' d/dry-run v/verbose h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "obsidian-session-sync (oss) - Synthesize Claude session into Obsidian"
        echo ""
        echo "USAGE:"
        echo "  oss                        # Sync current directory session"
        echo "  oss --worktree PATH        # Sync from a specific worktree"
        echo "  oss --ticket ISSUE-123     # Associate with a ticket"
        echo "  oss --dry-run              # Preview without writing"
        echo ""
        echo "OPTIONS:"
        echo "  -w, --worktree PATH  Worktree path (for gwt-ticket sessions)"
        echo "  -c, --cwd PATH      Project working directory"
        echo "  -t, --ticket ID      Ticket/issue ID to associate"
        echo "  -d, --dry-run        Print synthesis prompt without writing"
        echo "  -v, --verbose        Show gathered context"
        echo "  -h, --help           Show this help"
        return 0
    end

    set -l script "$HOME/dotfiles/scripts/obsidian/session-synthesize.sh"
    if not test -x "$script"
        echo "Error: session-synthesize.sh not found at $script" >&2
        return 1
    end

    set -l args
    if set -q _flag_worktree
        set -a args --worktree "$_flag_worktree"
    end
    if set -q _flag_cwd
        set -a args --cwd "$_flag_cwd"
    end
    if set -q _flag_ticket
        set -a args --ticket "$_flag_ticket"
    end
    if set -q _flag_dry_run
        set -a args --dry-run
    end
    if set -q _flag_verbose
        set -a args --verbose
    end

    bash "$script" $args
end
