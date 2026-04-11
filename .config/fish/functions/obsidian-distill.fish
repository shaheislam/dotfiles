function obsidian-distill --description "Batch memory distillation for unprocessed Obsidian session files"
    argparse 'l/limit=' d/dry-run p/priority v/verbose h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "obsidian-distill (odd) - Batch memory distillation for Obsidian sessions"
        echo ""
        echo "USAGE:"
        echo "  odd                    # Process 10 unprocessed sessions"
        echo "  odd --limit 50         # Process up to 50 sessions"
        echo "  odd --dry-run          # List what would be processed"
        echo "  odd --priority         # Process debugging > dev > research > planning first"
        echo "  odd --verbose          # Show per-file detail"
        echo ""
        echo "OPTIONS:"
        echo "  -l, --limit N    Process at most N sessions (default: 10)"
        echo "  -d, --dry-run    List files that would be processed, no side effects"
        echo "  -p, --priority   Order by work_type importance"
        echo "  -v, --verbose    Show per-file detail including session IDs"
        echo "  -h, --help       Show this help"
        echo ""
        echo "ENVIRONMENT:"
        echo "  OBSIDIAN_VAULT   Path to Obsidian vault (default: ~/obsidian)"
        return 0
    end

    set -l script "$HOME/dotfiles/scripts/obsidian/session-distill-batch.sh"
    if not test -x "$script"
        echo "Error: session-distill-batch.sh not found at $script" >&2
        return 1
    end

    set -l args
    if set -q _flag_limit
        set -a args --limit "$_flag_limit"
    end
    if set -q _flag_dry_run
        set -a args --dry-run
    end
    if set -q _flag_priority
        set -a args --priority
    end
    if set -q _flag_verbose
        set -a args --verbose
    end

    bash "$script" $args
end
