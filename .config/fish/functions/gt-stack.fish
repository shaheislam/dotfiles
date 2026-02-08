function gt-stack --description "Interactive Graphite stack viewer with PR status"
    # Usage: gt-stack [options]
    #
    # Shows the current Graphite stack with PR status, checks, and review info.
    # Wraps 'gt log' with enhanced terminal output and fzf integration.
    #
    # Options:
    #   --interactive, -i  Use fzf for branch selection
    #   --verbose, -v      Show detailed check status
    #   --web, -w          Open stack view in browser
    #   --help, -h         Show help

    set -l do_interactive false
    set -l do_verbose false
    set -l do_web false
    set -l show_help false

    for arg in $argv
        switch $arg
            case --interactive -i
                set do_interactive true
            case --verbose -v
                set do_verbose true
            case --web -w
                set do_web true
            case --help -h
                set show_help true
        end
    end

    if $show_help
        echo "gt-stack - Interactive Graphite stack viewer"
        echo ""
        echo "Usage: gt-stack [options]"
        echo ""
        echo "Options:"
        echo "  --interactive, -i  Use fzf for branch selection"
        echo "  --verbose, -v      Show detailed check status per PR"
        echo "  --web, -w          Open stack view in browser"
        echo "  --help, -h         Show help"
        echo ""
        echo "Aliases: gts (gt-stack), gtsi (gt-stack -i)"
        return 0
    end

    # Open in browser
    if $do_web
        if command -q gt
            gt pr --stack
        else
            set -l repo (_gt_queue_detect_repo)
            if test -n "$repo"
                set -l branch (git branch --show-current 2>/dev/null)
                open "https://app.graphite.dev/$repo/pulls/$branch"
            end
        end
        return 0
    end

    # Use gt log if available for native stack view
    if command -q gt
        echo ""
        set_color --bold white
        echo "Graphite Stack"
        set_color normal
        echo (string repeat -n 60 "─")
        gt log
        echo (string repeat -n 60 "─")

        # Enhance with PR status from GitHub
        if $do_verbose
            echo ""
            set_color --bold white
            echo "PR Status Details"
            set_color normal
            echo (string repeat -n 60 "─")

            set -l repo (_gt_queue_detect_repo)
            if test -n "$repo"
                set -l branch (git branch --show-current 2>/dev/null)
                set -l pr_data (gh pr view --repo $repo --json number,title,statusCheckRollup,reviewDecision,mergeable,autoMergeRequest 2>/dev/null)

                if test -n "$pr_data"
                    set -l pr_num (echo $pr_data | jq -r '.number')
                    set -l pr_title (echo $pr_data | jq -r '.title')
                    set -l mergeable (echo $pr_data | jq -r '.mergeable // "UNKNOWN"')
                    set -l review (echo $pr_data | jq -r '.reviewDecision // "NONE"')

                    printf "  PR #%s: %s\n" $pr_num $pr_title
                    printf "  Mergeable: %s  |  Review: %s\n" $mergeable $review

                    # Show individual checks
                    set -l checks (echo $pr_data | jq -r '.statusCheckRollup[]? | "\(.name)\t\(.conclusion // "PENDING")\t\(.status)"')
                    if test (count $checks) -gt 0
                        echo ""
                        printf "  %-40s %-12s %s\n" "CHECK" "RESULT" "STATUS"
                        printf "  %-40s %-12s %s\n" (string repeat -n 40 "─") (string repeat -n 12 "─") (string repeat -n 10 "─")
                        for check in $checks
                            set -l parts (string split \t $check)
                            set -l check_name $parts[1]
                            set -l conclusion $parts[2]
                            set -l check_status $parts[3]

                            if test (string length "$check_name") -gt 38
                                set check_name (string sub -l 35 "$check_name")"..."
                            end

                            # Colorize conclusion
                            switch $conclusion
                                case SUCCESS
                                    set_color green
                                case FAILURE
                                    set_color red
                                case PENDING
                                    set_color yellow
                                case '*'
                                    set_color brblack
                            end
                            printf "  %-40s %-12s %s\n" $check_name $conclusion $check_status
                            set_color normal
                        end
                    end
                end
            end
            echo ""
        end

        # Interactive mode with fzf
        if $do_interactive
            echo ""
            set -l branches (gt log 2>/dev/null | string match -r '^\s*[│├└─]*\s*(\S+)' | string trim)
            if test (count $branches) -gt 0; and command -q fzf
                set -l selected (printf '%s\n' $branches | fzf --prompt="Switch to > " --preview="git log --oneline -5 {}")
                if test -n "$selected"
                    gt checkout $selected
                end
            end
        end
    else
        # Fallback: show git branch structure
        echo ""
        set_color --bold white
        echo "Branch Stack (install gt for enhanced view)"
        set_color normal
        echo (string repeat -n 40 "─")

        set -l branch (git branch --show-current 2>/dev/null)
        set -l default_branch (__git.default_branch 2>/dev/null; or echo "main")

        # Show commits between default branch and current
        git log --oneline --graph "$default_branch".."$branch" 2>/dev/null
        echo ""
        echo "Install Graphite CLI for full stack visualization:"
        echo "  brew install withgraphite/tap/graphite"
    end
end
