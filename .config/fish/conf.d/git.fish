# Remove legacy hooks to prevent errors when upgrading.
functions -e _git_install _git_update _git_uninstall

# PERF: Skip git abbreviation setup in non-interactive shells (scripts, fish -c)
if not status is-interactive
    return
end

# PERF: Guard against redundant initialization if abbreviations already exist
if abbr --query g
    return
end

# fisher initialization, protected as omf also tries to run it.
set -q fisher_path; or set -l fisher_path $__fish_config_dir
if test -f $fisher_path/functions/__git.init.fish
    source $fisher_path/functions/__git.init.fish
    __git.init
end
