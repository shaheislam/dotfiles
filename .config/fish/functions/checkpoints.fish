function checkpoints --description "Manage agent session checkpoints via entire CLI (ckpt)"
    # Wrapper around the `entire` CLI (github.com/entireio/cli).
    # Provides backward-compatible aliases for the old checkpoints.sh commands.
    #
    # Usage:
    #   checkpoints enable [--strategy manual-commit|auto-commit]
    #   checkpoints disable
    #   checkpoints status
    #   checkpoints explain <sha>       (was: show)
    #   checkpoints resume [branch]
    #   checkpoints rewind
    #   checkpoints clean
    #   checkpoints reset
    #   checkpoints doctor
    #
    # Or use `entire` directly for full feature set.

    if not command -q entire
        echo "Error: entire CLI not found. Install with: brew tap entireio/tap && brew install entireio/tap/entire"
        return 1
    end

    # Translate legacy subcommands to entire equivalents
    set -l subcmd $argv[1]
    set -l rest $argv[2..]

    switch "$subcmd"
        case show
            # Legacy: ckpt show <sha> → entire explain <sha>
            entire explain $rest
        case log
            # Legacy: ckpt log → entire status (closest equivalent)
            entire status $rest
        case context
            # Legacy: ckpt context → entire resume (closest equivalent)
            entire resume $rest
        case search
            # No direct equivalent — suggest using git grep on entire branch
            echo "Note: 'search' not available in entire CLI. Use: git log --all --grep='$rest'"
            return 1
        case '*'
            # Pass through: enable, disable, status, resume, rewind, clean, reset, doctor
            entire $argv
    end
end
