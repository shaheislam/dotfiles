function __fzf_docker_sh
    # Get the absolute path to the parent directory of this script (i.e. the
    # parent directory of fzf-docker.sh) to use in the key bindings to avoid
    # having to modify `$PATH`.
    set --function fzf_docker_sh_path (realpath (status dirname))

    # Capture current token for FZF query (pre-fills search with partial input)
    set --function current_token (commandline -ct)

    # Run the FZF docker script and capture the result
    set --function result (FZF_DOCKER_QUERY="$current_token" SHELL=bash bash "$fzf_docker_sh_path/fzf-docker.sh" --run $argv | string join ' ')

    # Only insert the result if something was selected (not cancelled with ESC)
    if test -n "$result"
        commandline --insert "$result "
    end
end

set --local commands containers all_containers images volumes networks compose_services

for command in $commands
    set --function key (string sub --length=1 $command)

    eval "bind -M default \cd$key   '__fzf_docker_sh $command'"
    eval "bind -M insert  \cd$key   '__fzf_docker_sh $command'"
    eval "bind -M default \cd\c$key '__fzf_docker_sh $command'"
    eval "bind -M insert  \cd\c$key '__fzf_docker_sh $command'"
end
