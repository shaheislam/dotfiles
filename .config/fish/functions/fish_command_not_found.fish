# PERF: This file's mere existence prevents Fish's embedded config from probing
# for external command-not-found handlers (type -q command-not-found ~29ms +
# type -q pkgfile ~24ms = ~53ms savings at startup).
#
# At runtime, mise's cached init overrides this with its own handler that
# can suggest tool installation via `mise hook-not-found`.
function fish_command_not_found
    __fish_default_command_not_found_handler $argv
end
