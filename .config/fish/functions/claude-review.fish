function claude-review --description "Review PR diff with Claude Code (budget-capped headless mode)"
    # Usage: claude-review [PR_NUMBER] [options]
    #
    # Reviews a PR diff using Claude in print mode with safety caps.
    # Auto-detects current branch's PR if no number given.
    #
    # Options:
    #   --max-turns N      Max agentic turns (default: 3)
    #   --max-budget N     Max API spend in USD (default: 2.00)
    #   --model MODEL      Model to use (default: sonnet)
    #   --prompt TEXT       Custom review prompt
    #   --security         Focus on security vulnerabilities
    #   --json             Output structured JSON
    #   --schema FILE      JSON schema for structured output
    #   --help, -h         Show help

    set -l pr_number ""
    set -l max_turns 3
    set -l max_budget "2.00"
    set -l model sonnet
    set -l prompt "Review this diff for bugs, security issues, and code quality problems. Output only actionable feedback."
    set -l use_json false
    set -l json_schema ""
    set -l skip_next false

    for i in (seq (count $argv))
        if $skip_next
            set skip_next false
            continue
        end

        set -l arg $argv[$i]
        set -l next_i (math $i + 1)

        switch $arg
            case --help -h
                echo "Usage: claude-review [PR_NUMBER] [options]"
                echo ""
                echo "Review PR diff with Claude Code in budget-capped headless mode."
                echo "Auto-detects current branch's PR if no number given."
                echo ""
                echo "Options:"
                echo "  --max-turns N    Max agentic turns (default: 3)"
                echo "  --max-budget N   Max API spend in USD (default: 2.00)"
                echo "  --model MODEL    Model to use (default: sonnet)"
                echo "  --prompt TEXT    Custom review prompt"
                echo "  --security       Focus on security vulnerabilities"
                echo "  --json           Output structured JSON"
                echo "  --schema FILE    JSON schema for structured output"
                echo ""
                echo "Examples:"
                echo "  claude-review                    # Review current branch's PR"
                echo "  claude-review 447                # Review PR #447"
                echo "  claude-review --security         # Security-focused review"
                echo "  claude-review --json             # JSON output"
                echo "  claude-review --max-budget 5.00  # Higher budget for thorough review"
                return 0
            case --max-turns
                if test $next_i -le (count $argv)
                    set max_turns $argv[$next_i]
                    set skip_next true
                end
            case --max-budget
                if test $next_i -le (count $argv)
                    set max_budget $argv[$next_i]
                    set skip_next true
                end
            case --model
                if test $next_i -le (count $argv)
                    set model $argv[$next_i]
                    set skip_next true
                end
            case --prompt
                if test $next_i -le (count $argv)
                    set prompt $argv[$next_i]
                    set skip_next true
                end
            case --security
                set prompt "Audit this diff for security vulnerabilities: injection, auth bypass, data exposure, SSRF, path traversal. Output only high-confidence findings with file:line references."
            case --json
                set use_json true
            case --schema
                if test $next_i -le (count $argv)
                    set json_schema $argv[$next_i]
                    set skip_next true
                    set use_json true
                end
            case '*'
                if string match -qr '^\d+$' $arg
                    set pr_number $arg
                end
        end
    end

    # Auto-detect PR if not specified
    if test -z "$pr_number"
        set pr_number (gh pr view --json number -q '.number' 2>/dev/null)
        if test -z "$pr_number"
            echo "Error: No PR found for current branch. Pass a PR number: claude-review 447"
            return 1
        end
    end

    # Build claude command
    set -l claude_args -p --max-turns $max_turns --max-budget-usd $max_budget --model $model

    if $use_json
        set -a claude_args --output-format json
    end
    if test -n "$json_schema"
        set -a claude_args --json-schema $json_schema
    end

    echo "Reviewing PR #$pr_number (model: $model, max-turns: $max_turns, budget: \$$max_budget)"
    gh pr diff $pr_number | claude $claude_args "$prompt"
end
