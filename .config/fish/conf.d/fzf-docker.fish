# Source fzf-docker.sh integration for Fish shell
# This file auto-loads Docker FZF functionality at shell startup

# Only load if fzf and docker are available
if type -q fzf && type -q docker
    # Source the fzf-docker Fish integration
    source ~/.config/fish/functions/fzf-docker.fish
end
