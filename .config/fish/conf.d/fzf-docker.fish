# Source fzf-docker.sh integration for Fish shell
# This file auto-loads Docker FZF functionality at shell startup

# PERF: Deferred to fish_prompt event to avoid two expensive type -q calls at startup
# (~50-90ms savings with large PATH). Functions are available before user interaction.
if status is-interactive
    function __fzf_docker_init --on-event fish_prompt
        functions -e __fzf_docker_init # run once then remove
        if type -q fzf; and type -q docker
            source ~/.config/fish/functions/fzf-docker.fish
        end
    end
end
