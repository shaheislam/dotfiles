# Monthly changelog review for tracked tools
# Fetches release notes from GitHub, reviews dotfiles config for impact.
#
# Usage:
#   changelog-review              - Full review (last 30 days)
#   changelog-review fetch        - Fetch changelogs only
#   changelog-review config       - Review config only (requires prior fetch)
#   changelog-review --days 60    - Custom date range
#   changelog-review --category shell  - Filter by category
#   changelog-review --dry-run    - Show what would be checked

function changelog-review --description "Monthly tool changelog review with config impact analysis"
    set -l dotfiles_root ~/dotfiles
    set -l fetch_script "$dotfiles_root/scripts/harness/changelog-review.sh"
    set -l config_script "$dotfiles_root/scripts/harness/changelog-config-review.sh"

    if not test -f "$fetch_script"
        echo "Changelog review script not found at $fetch_script"
        return 1
    end

    # Parse subcommand
    set -l subcmd ""
    set -l pass_args

    if test (count $argv) -gt 0
        switch $argv[1]
            case fetch
                set subcmd fetch
                set pass_args $argv[2..]
            case config
                set subcmd config
                set pass_args $argv[2..]
            case '*'
                set subcmd all
                set pass_args $argv
        end
    else
        set subcmd all
    end

    switch $subcmd
        case fetch
            bash "$fetch_script" $pass_args
        case config
            bash "$config_script" $pass_args
        case all
            bash "$fetch_script" $pass_args
            and bash "$config_script"
    end
end
