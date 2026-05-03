function __fish_fisher_plugins
    command -q fisher; or return
    fisher list 2>/dev/null
end

complete --command fisher --exclusive --long help --description "Print help"
complete --command fisher --exclusive --long version --description "Print version"
complete --command fisher --exclusive --condition __fish_use_subcommand --arguments install --description "Install plugins"
complete --command fisher --exclusive --condition __fish_use_subcommand --arguments update --description "Update installed plugins"
complete --command fisher --exclusive --condition __fish_use_subcommand --arguments remove --description "Remove installed plugins"
complete --command fisher --exclusive --condition __fish_use_subcommand --arguments list --description "List installed plugins matching regex"
complete --command fisher --exclusive --condition "__fish_seen_subcommand_from update remove" --arguments "(__fish_fisher_plugins)"
