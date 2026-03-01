function checkpoints --description "Manage agent session checkpoints via entire CLI (ckpt)"
    # Wrapper around the `entire` CLI (github.com/entireio/cli).
    # Provides backward-compatible aliases for the old checkpoints.sh commands,
    # plus enhanced subcommands for attribution, generation, and explain modes.
    #
    # Usage:
    #   checkpoints enable [--strategy manual-commit|auto-commit] [--agent NAME]
    #   checkpoints disable
    #   checkpoints status
    #   checkpoints explain <sha> [--short|--full|--raw]
    #   checkpoints attribution [sha]
    #   checkpoints generate [checkpoint-id]
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
        case attribution
            # Show agent vs. human code contribution for a commit
            # Reads initial_attribution from checkpoint metadata on entire/checkpoints/v1
            set -l sha $rest[1]
            if test -z "$sha"
                set sha HEAD
            end
            # Resolve to full SHA
            set -l full_sha (git rev-parse "$sha" 2>/dev/null)
            if test $status -ne 0
                echo "Error: invalid commit reference '$sha'"
                return 1
            end
            # Look up checkpoint metadata for this commit
            if not git show-ref --quiet refs/heads/entire/checkpoints/v1 2>/dev/null
                echo "No checkpoints branch found"
                return 1
            end
            # Search metadata files for matching commit
            set -l found false
            for meta in (git ls-tree -r --name-only entire/checkpoints/v1 2>/dev/null | grep 'metadata.json$')
                set -l meta_sha (git show "entire/checkpoints/v1:$meta" 2>/dev/null | jq -r '.commit_sha // .commit // empty' 2>/dev/null)
                if test "$meta_sha" = "$full_sha"; or string match -q "$full_sha*" "$meta_sha"; or string match -q "$meta_sha*" "$full_sha"
                    set found true
                    echo "Checkpoint attribution for $sha ($full_sha):"
                    echo ""
                    git show "entire/checkpoints/v1:$meta" 2>/dev/null | jq -r '
                        if .initial_attribution then
                            "Agent: \(.initial_attribution.agent // "unknown")",
                            "Lines added: \(.initial_attribution.lines_added // "N/A")",
                            "Lines removed: \(.initial_attribution.lines_removed // "N/A")",
                            "Files changed: \(.initial_attribution.files_changed // "N/A")",
                            "Human edits: \(.initial_attribution.human_edits // "N/A")"
                        elif .agent then
                            "Agent: \(.agent)",
                            "(No detailed attribution data)"
                        else
                            "(No attribution data in checkpoint metadata)"
                        end
                    ' 2>/dev/null
                    break
                end
            end
            if not $found
                echo "No checkpoint found for commit $sha"
                return 1
            end
        case generate
            # On-demand AI summary generation for checkpoints
            entire explain --generate $rest
        case explain
            # Enhanced explain with output modes
            set -l sha ""
            set -l mode ""
            for arg in $rest
                switch "$arg"
                    case --short
                        set mode --short
                    case --full
                        set mode --full
                    case --raw --raw-transcript
                        set mode --raw-transcript
                    case '*'
                        if test -z "$sha"
                            set sha $arg
                        end
                end
            end
            if test -z "$sha"
                echo "Usage: ckpt explain <sha> [--short|--full|--raw]"
                return 1
            end
            if test -n "$mode"
                entire explain $mode $sha
            else
                entire explain $sha
            end
        case '*'
            # Pass through: enable, disable, status, resume, rewind, clean, reset, doctor
            entire $argv
    end
end
