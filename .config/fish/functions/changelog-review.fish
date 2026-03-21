# Monthly changelog review for tracked tools
# Launches gwt-ticket with changelog-review workflow template.
# The agent fetches release notes, reviews config, and makes fixes.
#
# Usage:
#   changelog-review              - Launch full review (gwt-ticket, last 30 days)
#   changelog-review fetch        - Fetch changelogs only (no agent)
#   changelog-review --days 60    - Custom date range
#   changelog-review --dry-run    - Show what would be checked (no agent)
#   changelog-review --category shell  - Filter by category

function changelog-review --description "Monthly tool changelog review via gwt-ticket"
    set -l dotfiles_root ~/dotfiles
    set -l fetch_script "$dotfiles_root/scripts/harness/changelog-review.sh"
    set -l days 30

    if not test -f "$fetch_script"
        echo "Changelog review script not found at $fetch_script"
        return 1
    end

    # Parse subcommand and flags
    set -l subcmd run
    set -l pass_args

    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case fetch
                set subcmd fetch
            case --days
                set i (math $i + 1)
                set days $argv[$i]
            case --dry-run
                set subcmd dry-run
            case --category
                set i (math $i + 1)
                set pass_args $pass_args --category $argv[$i]
            case '*'
                set pass_args $pass_args $argv[$i]
        end
        set i (math $i + 1)
    end

    switch $subcmd
        case fetch
            bash "$fetch_script" --days $days $pass_args
        case dry-run
            bash "$fetch_script" --dry-run --days $days $pass_args
        case run
            # Pre-fetch changelogs so the agent has data ready
            echo "Fetching changelogs (last $days days)..."
            bash "$fetch_script" --days $days $pass_args
            echo ""

            # Launch gwt-ticket with changelog-review template
            set -l title "Monthly changelog review"
            set -l desc "Review tool changelogs from the last $days days, update dotfiles config where warranted, and create atomic commits per tool."

            gwt-ticket TASK changelog-review "$title" "$desc" \
                --template changelog-review \
                --no-beads
    end
end
