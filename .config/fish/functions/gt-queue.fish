function gt-queue --description "Terminal-native Graphite merge queue viewer and manager"
    # Usage: gt-queue [command] [options]
    #
    # Commands:
    #   status    Show merge queue status for current repo (default)
    #   enqueue   Add current branch's PR to merge queue
    #   dequeue   Remove current branch's PR from merge queue
    #   list      List all PRs in the merge queue
    #   merge     Merge current stack via Graphite
    #   submit    Submit and mark PRs as merge-when-ready
    #   log       Show recent merge activity
    #   open      Open Graphite merge queue dashboard in browser
    #   watch     Auto-refresh queue status (Ctrl+C to stop)
    #   retry     Re-enqueue a PR that failed in the merge queue
    #   help      Show this help
    #
    # Options:
    #   --repo, -r    Override repo (default: auto-detect from git remote)
    #   --stack, -s   Apply action to entire stack
    #   --dry-run     Show what would be done without doing it
    #   --confirm     Ask for confirmation before actions
    #   --interval N  Refresh interval for watch (default: 30)
    #   --help, -h    Show help

    # Parse arguments
    set -l command "status"
    set -l repo ""
    set -l do_stack false
    set -l do_dry_run false
    set -l do_confirm false
    set -l show_help false
    set -l skip_next false
    set -l watch_interval 30

    for i in (seq (count $argv))
        if $skip_next
            set skip_next false
            continue
        end

        set -l arg $argv[$i]

        switch $arg
            case --help -h
                set show_help true
            case --repo -r
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set repo $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --repo requires a value"
                    return 1
                end
            case --interval
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set watch_interval $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --interval requires a value"
                    return 1
                end
            case --stack -s
                set do_stack true
            case --dry-run
                set do_dry_run true
            case --confirm
                set do_confirm true
            case status list enqueue dequeue merge submit log open watch retry help
                set command $arg
            case '-*'
                echo "Error: Unknown option: $arg"
                return 1
            case '*'
                # First positional arg is the command if not already set
                set command $arg
        end
    end

    # Show help
    if $show_help; or test "$command" = help
        _gt_queue_help
        return 0
    end

    # Validate prerequisites
    if not command -q gh
        echo "Error: gh (GitHub CLI) required. Install with: brew install gh"
        return 1
    end

    # Auto-detect repo from git remote
    if test -z "$repo"
        set repo (_gt_queue_detect_repo)
        if test -z "$repo"
            echo "Error: Could not detect repository. Use --repo owner/name"
            return 1
        end
    end

    # Dispatch command
    switch $command
        case status
            _gt_queue_status $repo
        case list
            _gt_queue_list $repo
        case enqueue
            _gt_queue_enqueue $repo $do_stack $do_dry_run $do_confirm
        case dequeue
            _gt_queue_dequeue $repo $do_dry_run $do_confirm
        case merge
            _gt_queue_merge $do_stack $do_dry_run $do_confirm
        case submit
            _gt_queue_submit $do_stack $do_dry_run
        case log
            _gt_queue_log $repo
        case open
            _gt_queue_open $repo
        case watch
            _gt_queue_watch $repo $watch_interval
        case retry
            _gt_queue_retry $repo $do_stack $do_dry_run $do_confirm
        case '*'
            echo "Error: Unknown command: $command"
            echo "Run 'gt-queue help' for usage"
            return 1
    end
end


function _gt_queue_help
    echo "gt-queue - Terminal-native Graphite merge queue manager"
    echo ""
    echo "Usage: gt-queue [command] [options]"
    echo ""
    echo "Commands:"
    echo "  status    Show merge queue status for current repo (default)"
    echo "  list      List all PRs in the merge queue"
    echo "  enqueue   Add current branch's PR to merge queue"
    echo "  dequeue   Remove current branch's PR from merge queue"
    echo "  merge     Merge current stack via Graphite (gt merge)"
    echo "  submit    Submit stack and enable merge-when-ready"
    echo "  log       Show recent merge activity"
    echo "  watch     Auto-refresh queue status (Ctrl+C to stop)"
    echo "  retry     Re-enqueue a PR that failed in the queue"
    echo "  open      Open Graphite merge queue dashboard in browser"
    echo "  help      Show this help"
    echo ""
    echo "Options:"
    echo "  --repo, -r      Override repo (default: auto-detect)"
    echo "  --stack, -s     Apply action to entire stack"
    echo "  --dry-run       Show what would be done"
    echo "  --confirm       Ask for confirmation"
    echo "  --interval N    Refresh interval for watch (default: 30s)"
    echo ""
    echo "Examples:"
    echo "  gt-queue                          # Show queue status"
    echo "  gt-queue list                     # List queued PRs"
    echo "  gt-queue enqueue                  # Add current PR to queue"
    echo "  gt-queue enqueue --stack          # Enqueue entire stack"
    echo "  gt-queue submit --stack           # Submit and merge-when-ready"
    echo "  gt-queue merge                    # Merge via Graphite"
    echo "  gt-queue log                      # Recent merge activity"
    echo "  gt-queue watch                    # Auto-refresh status"
    echo "  gt-queue watch --interval 10      # Refresh every 10s"
    echo "  gt-queue retry                    # Re-enqueue failed PR"
    echo "  gt-queue open                     # Open dashboard"
    echo ""
    echo "Aliases: gtq (status), gtqs (submit --stack), gtqm (merge), gtqw (watch)"
end


function _gt_queue_detect_repo
    # Extract owner/repo from git remote
    set -l remote_url (git remote get-url origin 2>/dev/null)
    if test -z "$remote_url"
        return 1
    end

    # Handle SSH format: git@github.com:owner/repo.git
    if string match -q "git@*" $remote_url
        set -l repo (string replace -r 'git@[^:]+:(.+?)(?:\.git)?$' '$1' $remote_url)
        echo $repo
        return 0
    end

    # Handle HTTPS format: https://github.com/owner/repo.git
    if string match -q "https://*" $remote_url
        set -l repo (string replace -r 'https://[^/]+/(.+?)(?:\.git)?$' '$1' $remote_url)
        echo $repo
        return 0
    end

    return 1
end


function _gt_queue_status --argument-names repo
    set -l branch (git branch --show-current 2>/dev/null)

    echo ""
    set_color --bold white
    echo "Merge Queue Status: $repo"
    set_color normal
    echo (string repeat -n 60 "─")

    # Get PRs that are in the merge queue (have auto-merge enabled or Graphite merge labels)
    set -l queued_prs (gh pr list --repo $repo --json number,title,headRefName,author,statusCheckRollup,labels,autoMergeRequest,mergeable,reviewDecision --search "is:open" 2>/dev/null)

    if test -z "$queued_prs"; or test "$queued_prs" = "[]"
        echo "  No open PRs found"
        echo ""
        return 0
    end

    # Parse and categorize PRs
    set -l total (echo $queued_prs | jq 'length')

    # Count queued PRs (auto-merge enabled or graphite merge label)
    set -l in_queue (echo $queued_prs | jq '[.[] | select(.autoMergeRequest != null or (.labels[]?.name // "" | test("merge|queue|graphite"; "i")))] | length')
    set -l merge_ready (echo $queued_prs | jq '[.[] | select(.mergeable == "MERGEABLE" and .reviewDecision == "APPROVED")] | length')
    set -l pending_checks (echo $queued_prs | jq '[.[] | select(.statusCheckRollup != null) | select([.statusCheckRollup[] | select(.conclusion == null or .conclusion == "PENDING")] | length > 0)] | length')
    set -l needs_review (echo $queued_prs | jq '[.[] | select(.reviewDecision == null or .reviewDecision == "REVIEW_REQUIRED")] | length')

    # Summary with color
    printf "  Open: "
    set_color --bold white
    printf "%s" $total
    set_color normal
    printf "  |  Queued: "
    set_color --bold green
    printf "%s" $in_queue
    set_color normal
    printf "  |  Ready: "
    set_color --bold cyan
    printf "%s" $merge_ready
    set_color normal
    printf "  |  Pending CI: "
    set_color --bold yellow
    printf "%s" $pending_checks
    set_color normal
    printf "  |  Needs Review: "
    set_color --bold red
    printf "%s" $needs_review
    set_color normal
    echo ""
    echo ""

    # Show stack PRs if gt is available
    if command -q gt; and test -n "$branch"
        set -l stack_branches (gt log --short 2>/dev/null | string trim)
        if test (count $stack_branches) -gt 1
            set_color --bold magenta
            echo "Stack PRs:"
            set_color normal
            for sb in $stack_branches
                set -l sb_pr (echo $queued_prs | jq --arg b "$sb" '[.[] | select(.headRefName == $b)] | first')
                if test "$sb_pr" != "null"; and test -n "$sb_pr"
                    set -l sb_num (echo $sb_pr | jq -r '.number')
                    set -l sb_title (echo $sb_pr | jq -r '.title')
                    set -l sb_mergeable (echo $sb_pr | jq -r '.mergeable // "UNKNOWN"')
                    set -l sb_review (echo $sb_pr | jq -r '.reviewDecision // "NONE"')
                    set -l sb_auto (echo $sb_pr | jq -r 'if .autoMergeRequest != null then "Q" else "-" end')

                    set -l marker "  "
                    if test "$sb" = "$branch"
                        set marker "> "
                        set_color cyan
                    end

                    printf "  %s#%-5s %-25s %s  %s  %s\n" \
                        $marker $sb_num \
                        (test (string length "$sb") -gt 23; and string sub -l 20 "$sb"; or echo "$sb") \
                        (_gt_queue_colorize_status $sb_mergeable) \
                        (_gt_queue_colorize_review $sb_review) \
                        (_gt_queue_colorize_auto_merge $sb_auto)
                    set_color normal
                end
            end
            echo ""
        end
    end

    # Current branch PR status
    if test -n "$branch"
        set -l current_pr (echo $queued_prs | jq --arg branch "$branch" '[.[] | select(.headRefName == $branch)] | first')
        if test "$current_pr" != "null"; and test -n "$current_pr"
            set_color --bold cyan
            echo "Current Branch: $branch"
            set_color normal

            set -l pr_num (echo $current_pr | jq -r '.number')
            set -l pr_title (echo $current_pr | jq -r '.title')
            set -l mergeable (echo $current_pr | jq -r '.mergeable // "UNKNOWN"')
            set -l review (echo $current_pr | jq -r '.reviewDecision // "NONE"')
            set -l auto_merge (echo $current_pr | jq -r 'if .autoMergeRequest != null then "ENABLED" else "DISABLED" end')

            # Detect Graphite merge queue labels
            set -l graphite_label (echo $current_pr | jq -r '[.labels[]?.name // "" | select(test("merge|queue|graphite"; "i"))] | first // ""')
            if test -n "$graphite_label"
                set auto_merge "QUEUED ($graphite_label)"
            end

            # Check status
            set -l check_status "UNKNOWN"
            set -l checks_passed 0
            set -l checks_total 0
            set -l checks_failed 0
            if test (echo $current_pr | jq '.statusCheckRollup | length') -gt 0
                set checks_total (echo $current_pr | jq '.statusCheckRollup | length')
                set checks_passed (echo $current_pr | jq '[.statusCheckRollup[] | select(.conclusion == "SUCCESS")] | length')
                set checks_failed (echo $current_pr | jq '[.statusCheckRollup[] | select(.conclusion == "FAILURE")] | length')
                if test $checks_failed -gt 0
                    set check_status "FAILING"
                else if test $checks_passed -eq $checks_total
                    set check_status "PASSING"
                else
                    set check_status "PENDING"
                end
            end

            printf "  PR #%s: %s\n" $pr_num $pr_title
            printf "  Mergeable: %s  |  Review: %s  |  Checks: %s (%s/%s)\n" \
                (_gt_queue_colorize_status $mergeable) \
                (_gt_queue_colorize_review $review) \
                (_gt_queue_colorize_checks $check_status) \
                $checks_passed $checks_total
            printf "  Auto-merge: %s\n" (_gt_queue_colorize_auto_merge $auto_merge)
            echo ""
        else
            set_color yellow
            echo "Current Branch: $branch (no PR found)"
            set_color normal
            echo ""
        end
    end

    # List queued PRs
    set -l queue_entries (echo $queued_prs | jq -r '[.[] | select(.autoMergeRequest != null or (.labels[]?.name // "" | test("merge|queue|graphite"; "i")))] | sort_by(.number) | .[] | "#\(.number)\t\(.headRefName)\t\(.title)\t\(.author.login)"')

    if test (count $queue_entries) -gt 0
        set_color --bold green
        echo "Queued PRs:"
        set_color normal
        printf "  %-8s %-30s %-40s %s\n" "PR" "BRANCH" "TITLE" "AUTHOR"
        printf "  %-8s %-30s %-40s %s\n" (string repeat -n 8 "─") (string repeat -n 30 "─") (string repeat -n 40 "─") (string repeat -n 12 "─")

        set -l position 0
        for entry in $queue_entries
            set position (math $position + 1)
            set -l parts (string split \t $entry)
            set -l pr_num $parts[1]
            set -l pr_branch $parts[2]
            set -l pr_title $parts[3]
            set -l pr_author $parts[4]

            # Truncate long values
            if test (string length "$pr_branch") -gt 28
                set pr_branch (string sub -l 25 "$pr_branch")"..."
            end
            if test (string length "$pr_title") -gt 38
                set pr_title (string sub -l 35 "$pr_title")"..."
            end

            # Highlight current branch
            if test "$pr_branch" = "$branch"
                set_color cyan
                printf "  %-8s %-30s %-40s %s  [pos %s]\n" $pr_num $pr_branch $pr_title $pr_author $position
                set_color normal
            else
                printf "  %-8s %-30s %-40s %s\n" $pr_num $pr_branch $pr_title $pr_author
            end
        end
        echo ""
    end

    echo (string repeat -n 60 "─")
    set_color brblack
    echo "Commands: enqueue | dequeue | merge | submit --stack | watch | open"
    set_color normal
end


function _gt_queue_list --argument-names repo
    echo ""
    set_color --bold white
    echo "All Open PRs: $repo"
    set_color normal
    echo (string repeat -n 80 "─")

    # Use fzf for interactive PR selection
    set -l prs (gh pr list --repo $repo --json number,title,headRefName,author,mergeable,reviewDecision,autoMergeRequest,statusCheckRollup --limit 50 2>/dev/null)

    if test -z "$prs"; or test "$prs" = "[]"
        echo "No open PRs found"
        return 0
    end

    set -l branch (git branch --show-current 2>/dev/null)

    # Build display lines for fzf
    set -l display_lines
    for line in (echo $prs | jq -r '.[] | "\(.number)\t\(.headRefName)\t\(.title)\t\(.author.login)\t\(if .autoMergeRequest != null then "QUEUED" else "-" end)\t\(.mergeable // "?")\t\(.reviewDecision // "-")"')
        set -a display_lines $line
    end

    if command -q fzf
        set -l selected (printf '%s\n' $display_lines | \
            fzf --header="PR#     BRANCH                    TITLE                            AUTHOR     QUEUE    MERGEABLE  REVIEW" \
                --delimiter='\t' \
                --preview="gh pr view {1} --repo $repo" \
                --preview-window=right:50%:wrap \
                --bind="ctrl-o:execute(gh pr view {1} --repo $repo --web)" \
                --bind="ctrl-e:execute(gh pr view {1} --repo $repo)" \
                --bind="ctrl-m:execute(echo {1})" \
                --prompt="Select PR > " \
                --height=80% \
                --border \
                --ansi)

        if test -n "$selected"
            set -l pr_num (echo $selected | string split \t | head -1)
            echo "Selected PR: $pr_num"
            gh pr view $pr_num --repo $repo
        end
    else
        # Fallback: table display
        printf "  %-6s %-25s %-35s %-12s %-8s %-12s %s\n" "PR#" "BRANCH" "TITLE" "AUTHOR" "QUEUE" "MERGEABLE" "REVIEW"
        printf "  %-6s %-25s %-35s %-12s %-8s %-12s %s\n" \
            (string repeat -n 6 "─") (string repeat -n 25 "─") (string repeat -n 35 "─") \
            (string repeat -n 12 "─") (string repeat -n 8 "─") (string repeat -n 12 "─") (string repeat -n 10 "─")

        for line in $display_lines
            set -l parts (string split \t $line)
            printf "  %-6s %-25s %-35s %-12s %-8s %-12s %s\n" $parts[1] $parts[2] $parts[3] $parts[4] $parts[5] $parts[6] $parts[7]
        end
    end
    echo ""
end


function _gt_queue_enqueue --argument-names repo do_stack do_dry_run do_confirm
    set -l branch (git branch --show-current 2>/dev/null)
    if test -z "$branch"
        echo "Error: Not on a branch"
        return 1
    end

    # Get PR number for current branch
    set -l pr_num (gh pr view --repo $repo --json number -q '.number' 2>/dev/null)
    if test -z "$pr_num"
        echo "Error: No PR found for branch '$branch'"
        echo "Create one with: gt submit"
        return 1
    end

    echo "Enqueuing PR #$pr_num ($branch)..."

    if test "$do_dry_run" = true
        echo "[DRY RUN] Would enable auto-merge for PR #$pr_num"
        if test "$do_stack" = true
            echo "[DRY RUN] Would also enqueue all downstack PRs"
        end
        return 0
    end

    if test "$do_confirm" = true
        read -l -P "Enable auto-merge for PR #$pr_num? [y/N] " confirm
        if test "$confirm" != "y"; and test "$confirm" != "Y"
            echo "Cancelled"
            return 0
        end
    end

    # Try Graphite CLI first (prefers merge queue if configured)
    if command -q gt
        if test "$do_stack" = true
            echo "Using Graphite: gt submit --stack --merge-when-ready"
            gt submit --stack --merge-when-ready
        else
            echo "Using Graphite: gt submit --merge-when-ready"
            gt submit --merge-when-ready
        end
    else
        # Fallback to gh CLI auto-merge
        echo "Using GitHub CLI: gh pr merge --auto"
        gh pr merge $pr_num --repo $repo --auto --squash
    end

    if test $status -eq 0
        set_color green
        echo "PR #$pr_num queued for merge"
        set_color normal
    else
        set_color red
        echo "Failed to enqueue PR #$pr_num"
        set_color normal
        return 1
    end
end


function _gt_queue_dequeue --argument-names repo do_dry_run do_confirm
    set -l branch (git branch --show-current 2>/dev/null)
    if test -z "$branch"
        echo "Error: Not on a branch"
        return 1
    end

    set -l pr_num (gh pr view --repo $repo --json number -q '.number' 2>/dev/null)
    if test -z "$pr_num"
        echo "Error: No PR found for branch '$branch'"
        return 1
    end

    echo "Removing PR #$pr_num ($branch) from merge queue..."

    if test "$do_dry_run" = true
        echo "[DRY RUN] Would disable auto-merge for PR #$pr_num"
        return 0
    end

    if test "$do_confirm" = true
        read -l -P "Disable auto-merge for PR #$pr_num? [y/N] " confirm
        if test "$confirm" != "y"; and test "$confirm" != "Y"
            echo "Cancelled"
            return 0
        end
    end

    gh pr merge $pr_num --repo $repo --disable-auto
    if test $status -eq 0
        set_color green
        echo "PR #$pr_num removed from merge queue"
        set_color normal
    else
        set_color red
        echo "Failed to dequeue PR #$pr_num"
        set_color normal
        return 1
    end
end


function _gt_queue_merge --argument-names do_stack do_dry_run do_confirm
    if not command -q gt
        echo "Error: Graphite CLI (gt) required for merge"
        echo "Install with: brew install withgraphite/tap/graphite"
        return 1
    end

    set -l args
    if test "$do_dry_run" = true
        set -a args "--dry-run"
    end
    if test "$do_confirm" = true
        set -a args "--confirm"
    end

    echo "Merging via Graphite..."
    gt merge $args
end


function _gt_queue_submit --argument-names do_stack do_dry_run
    if not command -q gt
        echo "Error: Graphite CLI (gt) required"
        echo "Install with: brew install withgraphite/tap/graphite"
        return 1
    end

    set -l args "--merge-when-ready"
    if test "$do_stack" = true
        set -a args "--stack"
    end
    if test "$do_dry_run" = true
        set -a args "--dry-run"
    end

    echo "Submitting with merge-when-ready..."
    gt submit $args
end


function _gt_queue_log --argument-names repo
    echo ""
    set_color --bold white
    echo "Recent Merge Activity: $repo"
    set_color normal
    echo (string repeat -n 60 "─")

    # Show recently merged PRs
    set -l merged (gh pr list --repo $repo --state merged --json number,title,headRefName,mergedAt,author --limit 15 2>/dev/null)

    if test -z "$merged"; or test "$merged" = "[]"
        echo "No recently merged PRs"
        return 0
    end

    printf "  %-6s %-20s %-35s %-12s %s\n" "PR#" "MERGED" "TITLE" "AUTHOR" "BRANCH"
    printf "  %-6s %-20s %-35s %-12s %s\n" \
        (string repeat -n 6 "─") (string repeat -n 20 "─") (string repeat -n 35 "─") \
        (string repeat -n 12 "─") (string repeat -n 20 "─")

    for line in (echo $merged | jq -r '.[] | "\(.number)\t\(.mergedAt | split("T")[0])\t\(.title)\t\(.author.login)\t\(.headRefName)"')
        set -l parts (string split \t $line)
        set -l pr_title $parts[3]
        if test (string length "$pr_title") -gt 33
            set pr_title (string sub -l 30 "$pr_title")"..."
        end
        printf "  %-6s %-20s %-35s %-12s %s\n" $parts[1] $parts[2] $pr_title $parts[4] $parts[5]
    end
    echo ""
end


function _gt_queue_open --argument-names repo
    # Graphite dashboard lives at app.graphite.dev
    set -l url "https://app.graphite.dev/github/pr/$repo"
    echo "Opening: $url"
    open $url 2>/dev/null; or xdg-open $url 2>/dev/null
end


function _gt_queue_watch --argument-names repo interval
    if test -z "$interval"
        set interval 30
    end

    echo ""
    set_color --bold white
    echo "Watching merge queue: $repo (every "$interval"s, Ctrl+C to stop)"
    set_color normal
    echo ""

    while true
        # Clear screen and show header
        printf "\033[2J\033[H"
        set_color brblack
        echo (date "+%H:%M:%S")" - Refreshing every "$interval"s (Ctrl+C to stop)"
        set_color normal

        _gt_queue_status $repo

        sleep $interval
    end
end


function _gt_queue_retry --argument-names repo do_stack do_dry_run do_confirm
    set -l branch (git branch --show-current 2>/dev/null)
    if test -z "$branch"
        echo "Error: Not on a branch"
        return 1
    end

    set -l pr_num (gh pr view --repo $repo --json number -q '.number' 2>/dev/null)
    if test -z "$pr_num"
        echo "Error: No PR found for branch '$branch'"
        return 1
    end

    echo "Retrying PR #$pr_num ($branch) - disabling then re-enabling auto-merge..."

    if test "$do_dry_run" = true
        echo "[DRY RUN] Would disable and re-enable auto-merge for PR #$pr_num"
        return 0
    end

    if test "$do_confirm" = true
        read -l -P "Retry auto-merge for PR #$pr_num? [y/N] " confirm
        if test "$confirm" != "y"; and test "$confirm" != "Y"
            echo "Cancelled"
            return 0
        end
    end

    # Disable auto-merge first
    gh pr merge $pr_num --repo $repo --disable-auto 2>/dev/null

    # Small delay to let GitHub process
    sleep 2

    # Re-enable via Graphite or GitHub
    if command -q gt
        if test "$do_stack" = true
            gt submit --stack --merge-when-ready
        else
            gt submit --merge-when-ready
        end
    else
        gh pr merge $pr_num --repo $repo --auto --squash
    end

    if test $status -eq 0
        set_color green
        echo "PR #$pr_num re-queued for merge"
        set_color normal
    else
        set_color red
        echo "Failed to re-queue PR #$pr_num"
        set_color normal
        return 1
    end
end


# Colorization helpers
function _gt_queue_colorize_status --argument-names merge_status
    switch $merge_status
        case MERGEABLE
            set_color green
            echo -n $merge_status
            set_color normal
        case CONFLICTING
            set_color red
            echo -n $merge_status
            set_color normal
        case '*'
            set_color yellow
            echo -n $merge_status
            set_color normal
    end
end


function _gt_queue_colorize_review --argument-names review
    switch $review
        case APPROVED
            set_color green
            echo -n $review
            set_color normal
        case CHANGES_REQUESTED
            set_color red
            echo -n $review
            set_color normal
        case REVIEW_REQUIRED
            set_color yellow
            echo -n $review
            set_color normal
        case '*'
            set_color brblack
            echo -n $review
            set_color normal
    end
end


function _gt_queue_colorize_checks --argument-names check_state
    switch $check_state
        case PASSING
            set_color green
            echo -n $check_state
            set_color normal
        case FAILING
            set_color red
            echo -n $check_state
            set_color normal
        case PENDING
            set_color yellow
            echo -n $check_state
            set_color normal
        case '*'
            set_color brblack
            echo -n $check_state
            set_color normal
    end
end


function _gt_queue_colorize_auto_merge --argument-names auto_state
    switch $auto_state
        case ENABLED
            set_color green
            echo -n $auto_state
            set_color normal
        case 'QUEUED*'
            set_color --bold green
            echo -n $auto_state
            set_color normal
        case Q
            set_color green
            echo -n "QUEUED"
            set_color normal
        case DISABLED -
            set_color brblack
            echo -n $auto_state
            set_color normal
        case '*'
            echo -n $auto_state
    end
end
